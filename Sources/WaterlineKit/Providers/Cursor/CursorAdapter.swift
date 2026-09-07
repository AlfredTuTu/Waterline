import Foundation

public struct CursorAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .cursor, kind: .window, docStatus: .community,
        allowedHosts: ["cursor.com"], consoleURL: URL(string: "https://cursor.com/dashboard")!)

    public init() {}

    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        let url = environment.home.appending(path: "Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        guard environment.fileSystem.exists(url) else { return [] }
        let reference = CredentialRef.file(path: url.path)
        do {
            guard let secret = try environment.credentialDatabase.cursorAccessToken(at: url) else { return [] }
            let subject = try Self.subject(secret)
            return [
                Discovered(
                    account: Account(
                        provider: .cursor, credential: reference,
                        identity: BillingIdentity(region: "cursor.com", account: subject)), secret: secret)
            ]
        } catch {
            return [
                Discovered(
                    account: Account(provider: .cursor, credential: reference), secret: nil,
                    connectionError: (error as? FetchError) ?? .transport(detail: "Could not read Cursor login"))
            ]
        }
    }

    static func subject(_ secret: Secret) throws -> String {
        let token = secret.value
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty }),
            token.utf8.allSatisfy({
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                    || [45, 95, 46].contains($0)
            })
        else { throw FetchError.schemaChanged(detail: "Cursor.accessToken") }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        struct Claims: Decodable { let sub: String }
        guard let data = Data(base64Encoded: payload), let claims = try? JSONDecoder().decode(Claims.self, from: data),
            let subject = claims.sub.split(separator: "|").last.map(String.init), !subject.isEmpty,
            subject.utf8.allSatisfy({
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [45, 95].contains($0)
            })
        else { throw FetchError.schemaChanged(detail: "Cursor.accessToken.sub") }
        return subject
    }

    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        let subject = try Self.subject(secret)
        guard account.provider == .cursor, account.identity?.region == "cursor.com",
            account.identity?.account == subject
        else { throw FetchError.credentialMissing }
        let headers = [
            "Cookie": "WorkosCursorSessionToken=\(subject)%3A%3A\(secret.value)", "Accept": "application/json",
        ]
        let response = try await http.send(
            HTTPRequest(url: URL(string: "https://cursor.com/api/usage-summary")!, headers: headers))
        try response.validateStatus()
        let summary = try Self.parse(response.body)
        var windows = summary.quotaWindows
        var failures = summary.componentFailures
        do {
            var sandHeaders = headers
            sandHeaders["Content-Type"] = "application/json"
            sandHeaders["Origin"] = "https://cursor.com"
            let sand = try await http.send(
                HTTPRequest(
                    url: URL(string: "https://cursor.com/api/dashboard/get-sand-usage-status")!,
                    method: "POST", headers: sandHeaders, body: Data("{}".utf8)))
            if sand.status != 404 {
                try sand.validateStatus()
                if let window = try Self.parseGrok(sand.body) { windows.append(window) }
            }
        } catch {
            failures.append(
                MetricFailure(
                    id: "grok-bot", error: (error as? FetchError) ?? .transport(detail: "Grok Bot usage unavailable")))
        }
        do {
            let url = URL(string: "https://cursor.com/api/usage")!.appending(queryItems: [
                URLQueryItem(name: "user", value: subject)
            ])
            let legacy = try await http.send(HTTPRequest(url: url, headers: headers))
            if legacy.status != 404 {
                try legacy.validateStatus()
                let metadata = try JSONDecoder().decode(Metadata.self, from: response.body)
                if let quota = try Self.parseRequestUsage(
                    legacy.body, resetsAt: Self.date(metadata.billingCycleEnd, path: "billingCycleEnd"))
                {
                    if quota.usedFraction != nil {
                        windows.removeAll {
                            [
                                "individualUsage.plan", "individualUsage.plan.autoPercentUsed",
                                "individualUsage.plan.apiPercentUsed",
                            ].contains($0.id ?? "")
                        }
                    }
                    windows.append(quota)
                }
            }
        } catch {
            failures.append(
                MetricFailure(
                    id: "legacy-requests",
                    error: (error as? FetchError) ?? .transport(detail: "Request quota unavailable")))
        }
        return .metrics(windows: windows, balances: [], plan: summary.planLabel, failures: failures)
    }

    public static func parse(_ data: Data) throws -> Usage {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            root["individualUsage"] is [String: Any] || root["teamUsage"] is [String: Any]
        else { throw FetchError.schemaChanged(detail: "usage-summary.individualUsage/teamUsage") }
        let metadata: Metadata
        do { metadata = try JSONDecoder().decode(Metadata.self, from: data) } catch {
            throw schemaError(error, prefix: "usage-summary")
        }
        let reset = try date(metadata.billingCycleEnd, path: "billingCycleEnd")
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        for (scope, key, label) in [
            ("individualUsage", "plan", "Included"), ("individualUsage", "overall", "Personal cap"),
            ("individualUsage", "onDemand", "On-demand"), ("teamUsage", "pooled", "Team pool"),
            ("teamUsage", "onDemand", "Team on-demand"),
        ] {
            let id = "\(scope).\(key)"
            guard let group = root[scope] as? [String: Any], let object = group[key], !(object is NSNull) else {
                continue
            }
            do {
                let block = try JSONDecoder().decode(
                    Block.self, from: JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]))
                guard [block.used, block.limit].compactMap({ $0 }).allSatisfy({ $0 >= 0 }) else {
                    throw FetchError.schemaChanged(detail: id)
                }
                let total = try percent(block.totalPercentUsed, path: id + ".totalPercentUsed")
                let ratio: Double? = block.used.flatMap { used in
                    block.limit.flatMap { $0 > 0 ? min(1, Double(used) / Double($0)) : nil }
                }
                let hasModelPools = block.autoPercentUsed != nil || block.apiPercentUsed != nil
                if let total, !hasModelPools {
                    windows.append(
                        UsageWindow(
                            label: label, usedFraction: total, resetsAt: reset,
                            id: id, failureScopes: [id]))
                }
                let hasQuotaPercent = total != nil || block.autoPercentUsed != nil || block.apiPercentUsed != nil
                if block.used != nil || block.limit != nil || block.enabled == false {
                    windows.append(
                        UsageWindow(
                            label: hasQuotaPercent ? "\(label) spend" : label,
                            usedFraction: hasQuotaPercent ? nil : ratio, resetsAt: reset,
                            id: hasQuotaPercent ? id + ".spend" : id, failureScopes: [id],
                            used: block.used.map { Decimal($0) / 100 },
                            limit: block.limit.map { Decimal($0) / 100 }, unit: "USD",
                            note: block.enabled == false
                                ? "Disabled"
                                : hasQuotaPercent ? "Reported spending; quota percentages shown separately." : nil))
                }
                for (field, name, value) in [
                    ("autoPercentUsed", "Cursor Models", block.autoPercentUsed),
                    ("apiPercentUsed", "Other Models", block.apiPercentUsed),
                ] {
                    if let fraction = try percent(value, path: id + "." + field) {
                        windows.append(
                            UsageWindow(
                                label: name, usedFraction: fraction, resetsAt: reset,
                                id: id + "." + field, failureScopes: [id]))
                    }
                }
            } catch {
                windows.removeAll { $0.failureScopes?.contains(id) == true }
                failures.append(MetricFailure(id: id, error: (error as? FetchError) ?? schemaError(error, prefix: id)))
            }
        }
        return .metrics(windows: windows, balances: [], plan: metadata.membershipType, failures: failures)
    }

    public static func parseRequestUsage(_ data: Data, resetsAt: Date? = nil) throws -> UsageWindow? {
        struct Requests: Decodable {
            let numRequests: Int64?
            let numRequestsTotal: Int64?
            let maxRequestUsage: Int64?
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw FetchError.schemaChanged(detail: "legacy-requests")
        }
        guard let block = root["gpt-4"], !(block is NSNull) else { return nil }
        let value: Requests
        do {
            value = try JSONDecoder().decode(
                Requests.self,
                from: JSONSerialization.data(withJSONObject: block, options: [.fragmentsAllowed]))
        } catch { throw schemaError(error, prefix: "legacy-requests.gpt-4") }
        guard let limit = value.maxRequestUsage else { return nil }
        let used = value.numRequestsTotal ?? value.numRequests
        guard limit >= 0, used.map({ $0 >= 0 }) ?? true else {
            throw FetchError.schemaChanged(detail: "legacy-requests.gpt-4.counts")
        }
        return UsageWindow(
            label: "Request quota", usedFraction: used.flatMap { limit > 0 ? min(1, Double($0) / Double(limit)) : nil },
            resetsAt: resetsAt, id: "legacy-requests", used: used.map(Decimal.init), limit: Decimal(limit),
            unit: "requests")
    }

    public static func parseGrok(_ data: Data) throws -> UsageWindow? {
        struct Grok: Decodable {
            let hasNonZeroIncludedLimit: Bool; let usagePercent: Double?; let nextResetTimestampUtc: String?
        }
        let value: Grok
        do { value = try JSONDecoder().decode(Grok.self, from: data) } catch {
            throw schemaError(error, prefix: "grok-bot")
        }
        guard value.hasNonZeroIncludedLimit else { return nil }
        return UsageWindow(
            label: "Grok Bot", usedFraction: try percent(value.usagePercent, path: "grok-bot.usagePercent"),
            resetsAt: try date(value.nextResetTimestampUtc, path: "grok-bot.nextResetTimestampUtc"), group: "grok-bot",
            id: "grok-bot", durationSeconds: 7 * 86400)
    }

    private static func percent(_ value: Double?, path: String) throws -> Double? {
        guard let value else { return nil }
        guard value.isFinite, (0...100).contains(value) else { throw FetchError.schemaChanged(detail: path) }
        return value / 100
    }

    private static func date(_ value: String?, path: String) throws -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else { throw FetchError.schemaChanged(detail: path) }
        return date
    }

    private struct Block: Decodable {
        let enabled: Bool?
        let used: Int64?
        let limit: Int64?
        let totalPercentUsed: Double?
        let autoPercentUsed: Double?
        let apiPercentUsed: Double?
    }
    private struct Metadata: Decodable { let billingCycleEnd: String?; let membershipType: String? }
}
