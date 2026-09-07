import Foundation

public struct KimiCodeAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .kimiCode, kind: .window, docStatus: .community,
        allowedHosts: ["api.kimi.com", "api.kimi.ai"], consoleURL: URL(string: "https://www.kimi.com/code/console")!,
        supportsManualKey: true,
        manualRegions: [
            ManualRegion(id: "cn", label: "China", host: "api.kimi.com"),
            ManualRegion(id: "global", label: "International", host: "api.kimi.ai"),
        ],
        regionalConsoleURLs: [
            "cn": URL(string: "https://www.kimi.com/code/console")!,
            "global": URL(string: "https://www.kimi.ai/code/console")!,
        ])
    public init() {}
    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] { [] }

    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        // Existing regionless manual accounts were created against the original .com-only contract.
        let regionID = account.region ?? "cn"
        guard account.provider == .kimiCode, account.credential == .manual,
            let region = Self.descriptor.manualRegions.first(where: { $0.id == regionID }),
            account.identity == nil || account.identity?.region == region.host
        else { throw ManualKeyError.invalidRegion }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://\(region.host)/coding/v1/usages")!,
                headers: ["Authorization": "Bearer \(secret.value)", "Accept": "application/json"]))
        try response.validateStatus()
        return try Self.parse(response.body)
    }

    public static func parse(_ data: Data) throws -> Usage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.schemaChanged(detail: "usage")
        }
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        func append(_ object: Any?, id: String, label: String, scope: [String]? = nil, duration: TimeInterval? = nil) {
            do {
                guard let object = object as? [String: Any] else { throw FetchError.schemaChanged(detail: id) }
                let detail: Detail
                do {
                    detail = try JSONDecoder().decode(Detail.self, from: JSONSerialization.data(withJSONObject: object))
                } catch { throw schemaError(error, prefix: id) }
                let total = try count(detail.limit, path: "\(id).limit")
                let reportedUsed = try detail.used.map { try count($0, path: "\(id).used") }
                let remaining = try detail.remaining.map { try count($0, path: "\(id).remaining") }
                let used = reportedUsed ?? remaining.map { total - $0 }
                if let used, used < 0 || used > total { throw FetchError.schemaChanged(detail: "\(id).used") }
                let fraction: Double?
                if let used, total > 0 {
                    let ratio = used / total
                    guard !ratio.isNaN, let value = Double(ratio.description), value.isFinite else {
                        throw FetchError.schemaChanged(detail: "\(id).limit/used")
                    }
                    fraction = value
                } else {
                    fraction = nil
                }
                let reset: Date?
                if let raw = detail.resetTime {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let parsed = formatter.date(from: raw) {
                        reset = parsed
                    } else {
                        formatter.formatOptions = [.withInternetDateTime]
                        guard let parsed = formatter.date(from: raw) else {
                            throw FetchError.schemaChanged(detail: "\(id).resetTime")
                        }
                        reset = parsed
                    }
                } else {
                    reset = nil
                }
                windows.append(
                    UsageWindow(
                        label: label, usedFraction: fraction, resetsAt: reset,
                        group: id == "usage" ? "subscription" : "primary", id: id, failureScopes: scope, used: used,
                        limit: total, unit: "quota units", durationSeconds: duration))
            } catch {
                failures.append(MetricFailure(id: id, error: (error as? FetchError) ?? .schemaChanged(detail: id)))
            }
        }
        append(root["usage"], id: "usage", label: "Subscription")
        if let limits = root["limits"], !(limits is NSNull) {
            if let entries = limits as? [Any] {
                var seen: Set<String> = []
                for (index, rawEntry) in entries.enumerated() {
                    do {
                        guard let entry = rawEntry as? [String: Any] else {
                            throw FetchError.schemaChanged(detail: "limits.\(index)")
                        }
                        guard let object = entry["window"] as? [String: Any] else {
                            throw FetchError.schemaChanged(detail: "limits.\(index).window")
                        }
                        let window = try JSONDecoder().decode(
                            Window.self, from: JSONSerialization.data(withJSONObject: object))
                        let multiplier: Int
                        switch window.timeUnit {
                        case "TIME_UNIT_MINUTE": multiplier = 1
                        case "TIME_UNIT_HOUR": multiplier = 60
                        case "TIME_UNIT_DAY": multiplier = 1440
                        default: throw FetchError.schemaChanged(detail: "limits.\(index).window.timeUnit")
                        }
                        let (minutes, overflow) = window.duration.multipliedReportingOverflow(by: multiplier)
                        guard window.duration > 0, !overflow else {
                            throw FetchError.schemaChanged(detail: "limits.\(index).window.duration")
                        }
                        let id = "limits.\(window.timeUnit).\(window.duration)"
                        guard seen.insert(id).inserted else {
                            windows.removeAll { $0.id == id }
                            failures.append(
                                MetricFailure(
                                    id: id, error: .schemaChanged(detail: "limits.\(index).window (duplicate)")))
                            continue
                        }
                        let label =
                            minutes % 1440 == 0
                            ? "\(minutes / 1440)d" : minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes)m"
                        append(entry["detail"], id: id, label: label, scope: ["limits"], duration: Double(minutes) * 60)
                    } catch {
                        failures.append(
                            MetricFailure(
                                id: "limits.\(index)",
                                error: (error as? FetchError) ?? .schemaChanged(detail: "limits.\(index).window")))
                    }
                }
            } else {
                failures.append(MetricFailure(id: "limits", error: .schemaChanged(detail: "limits")))
            }
        }
        let plan = ((root["user"] as? [String: Any])?["membership"] as? [String: Any])?["level"] as? String
        return .metrics(
            windows: windows, balances: [], plan: plan == "LEVEL_UNSPECIFIED" ? nil : plan, failures: failures)
    }

    private static func count(_ value: String, path: String) throws -> Decimal {
        guard value.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
            let number = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")), !number.isNaN
        else { throw FetchError.schemaChanged(detail: path) }
        return number
    }
    private struct Detail: Decodable {
        let limit: String
        let used: String?
        let remaining: String?
        let resetTime: String?
        enum CodingKeys: String, CodingKey { case limit, used, remaining, resetTime }
        init(from decoder: any Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            limit = try fields.decode(String.self, forKey: .limit)
            used = try fields.decodeIfPresent(String.self, forKey: .used)
            remaining = used == nil ? try fields.decodeIfPresent(String.self, forKey: .remaining) : nil
            resetTime = try fields.decodeIfPresent(String.self, forKey: .resetTime)
        }
    }
    private struct Window: Decodable { let duration: Int; let timeUnit: String }
}
