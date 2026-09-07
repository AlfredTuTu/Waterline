import Foundation

public struct ClaudeCodeAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .claudeCode, kind: .window, docStatus: .community,
        allowedHosts: ["api.anthropic.com"], consoleURL: URL(string: "https://claude.ai/settings/usage")!)

    public init() {}

    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        let items = try environment.keychain.items(service: "Claude Code-credentials")
        var results: [Discovered] = []
        if items.isEmpty {
            let url = environment.home.appending(path: ".claude/.credentials.json")
            guard environment.fileSystem.exists(url) else { return [] }
            results.append(
                await identify(
                    data: { try environment.fileSystem.contents(of: url) },
                    reference: .file(path: url.path), http: http))
        } else {
            for item in items {
                results.append(
                    await identify(
                        data: {
                            Data(
                                try environment.keychain.secret(
                                    for: item, allowsUserInteraction: environment.allowsUserInteraction
                                ).value.utf8)
                        }, reference: .keychain(service: item.service, account: item.account), http: http))
            }
        }
        return results
    }

    private func identify(data: () throws -> Data, reference: CredentialRef, http: any HTTPClient) async -> Discovered {
        let provisional = Account(provider: .claudeCode, credential: reference)
        do {
            let credentials: Credentials
            do { credentials = try JSONDecoder().decode(Credentials.self, from: data()) } catch let error as FetchError
            { throw error } catch { throw schemaError(error, prefix: "credentials") }
            guard let oauth = credentials.claudeAiOauth, !oauth.accessToken.isEmpty else {
                throw FetchError.credentialMissing
            }
            let secret = Secret(oauth.accessToken)
            let profile = try await http.send(
                HTTPRequest(
                    url: URL(string: "https://api.anthropic.com/api/oauth/profile")!,
                    headers: ["Authorization": "Bearer \(secret.value)", "Accept": "application/json"]))
            try profile.validateStatus()
            let identity = try Self.parseIdentity(profile.body)
            return Discovered(
                account: Account(
                    provider: .claudeCode, credential: reference, identity: identity, plan: oauth.subscriptionType),
                secret: secret)
        } catch {
            return Discovered(
                account: provisional, secret: nil,
                connectionError: (error as? FetchError) ?? .transport(detail: "Could not read Claude login"))
        }
    }

    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .claudeCode, account.identity?.region == "api.anthropic.com" else {
            throw FetchError.credentialMissing
        }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
                headers: [
                    "Authorization": "Bearer \(secret.value)", "anthropic-beta": "oauth-2025-04-20",
                    "Accept": "application/json", "User-Agent": "Waterline/\(WaterlineVersion.current)",
                ]))
        try response.validateStatus()
        return try Self.parse(response.body, plan: account.plan)
    }

    static func parseIdentity(_ data: Data) throws -> BillingIdentity {
        struct Profile: Decodable {
            struct Identity: Decodable { let uuid: String }
            let account: Identity
            let organization: Identity
        }
        do {
            let profile = try JSONDecoder().decode(Profile.self, from: data)
            guard UUID(uuidString: profile.account.uuid) != nil, UUID(uuidString: profile.organization.uuid) != nil
            else {
                throw FetchError.schemaChanged(detail: "profile.account.uuid/organization.uuid")
            }
            return BillingIdentity(
                region: "api.anthropic.com", account: profile.organization.uuid, subject: profile.account.uuid)
        } catch let error as FetchError { throw error } catch { throw schemaError(error, prefix: "profile") }
    }

    public static func parse(_ data: Data, plan: String? = nil) throws -> Usage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.schemaChanged(detail: "usage")
        }
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        let fields = [
            ("five_hour", "5h"), ("seven_day", "7d"), ("seven_day_opus", "Opus · 7d"),
            ("seven_day_sonnet", "Sonnet · 7d"), ("seven_day_oauth_apps", "OAuth apps · 7d"),
            ("seven_day_routines", "Routines · 7d"),
        ]
        for (key, label) in fields {
            guard let value = root[key], !(value is NSNull) else { continue }
            do {
                guard let object = value as? [String: Any] else { throw FetchError.schemaChanged(detail: key) }
                let window: Window
                do {
                    window = try JSONDecoder().decode(Window.self, from: JSONSerialization.data(withJSONObject: object))
                } catch { throw schemaError(error, prefix: key) }
                if let percent = window.utilization, !percent.isFinite || !(0...100).contains(percent) {
                    throw FetchError.schemaChanged(detail: "\(key).utilization")
                }
                let reset = try Self.date(window.resets_at, path: "\(key).resets_at")
                windows.append(
                    UsageWindow(
                        label: label, usedFraction: window.utilization.map { $0 / 100 }, resetsAt: reset,
                        group: key == "five_hour" || key == "seven_day" ? "primary" : key, id: key,
                        durationSeconds: key == "five_hour" ? 5 * 3600 : 7 * 86400))
            } catch {
                failures.append(MetricFailure(id: key, error: (error as? FetchError) ?? .schemaChanged(detail: key)))
            }
        }
        let scoped = Self.scopedLimits(root["limits"])
        windows += scoped.windows
        failures += scoped.failures
        return .metrics(windows: windows, balances: [], plan: plan, failures: failures)
    }

    static func date(_ value: String?, path: String) throws -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else { throw FetchError.schemaChanged(detail: path) }
        return date
    }

    private struct Credentials: Decodable { let claudeAiOauth: OAuth? }
    private struct OAuth: Decodable { let accessToken: String; let subscriptionType: String? }
    private struct Window: Decodable { let utilization: Double?; let resets_at: String? }
}
