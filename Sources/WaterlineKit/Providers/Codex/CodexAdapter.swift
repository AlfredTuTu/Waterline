import Foundation

public struct CodexAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .codex, kind: .window, docStatus: .official, allowedHosts: ["chatgpt.com"],
        consoleURL: URL(string: "https://chatgpt.com/codex/settings/usage")!)

    public init() {}

    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        let url = environment.home.appending(path: ".codex/auth.json")
        guard environment.fileSystem.exists(url) else { return [] }
        let auth: Auth
        do {
            auth = try JSONDecoder().decode(Auth.self, from: environment.fileSystem.contents(of: url))
        } catch { throw schemaError(error, prefix: "auth") }
        guard auth.auth_mode == "chatgpt", let tokens = auth.tokens else { return [] }
        guard !tokens.access_token.isEmpty, !tokens.account_id.isEmpty,
            !tokens.account_id.contains(where: \.isNewline)
        else { throw FetchError.credentialMissing }
        // The subject separates per-user quota within a shared billing account.
        let parts = tokens.id_token.split(separator: ".")
        guard parts.count == 3 else { throw FetchError.schemaChanged(detail: "auth.tokens.id_token") }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
            let claims = try? JSONDecoder().decode(Claims.self, from: data), !claims.sub.isEmpty
        else { throw FetchError.schemaChanged(detail: "auth.tokens.id_token.sub") }
        let account = Account(
            provider: .codex, credential: .file(path: url.path),
            identity: BillingIdentity(region: "chatgpt.com", account: tokens.account_id, subject: claims.sub))
        return [Discovered(account: account, secret: Secret(tokens.access_token))]
    }

    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .codex, let identity = account.identity, identity.region == "chatgpt.com" else {
            throw FetchError.credentialMissing
        }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
                headers: [
                    "Authorization": "Bearer \(secret.value)", "ChatGPT-Account-Id": identity.account,
                    "User-Agent": "Waterline/\(WaterlineVersion.current)",
                ]))
        try response.validateStatus()
        return try Self.parse(response.body)
    }

    public static func parse(_ data: Data) throws -> Usage {
        let root: [String: Any]
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FetchError.schemaChanged(detail: "usage")
            }
            root = object
        } catch { throw FetchError.schemaChanged(detail: "usage") }
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        func append(_ value: Any?, path: String, name: String) {
            guard let value, !(value is NSNull) else { return }
            guard let limits = value as? [String: Any] else {
                failures.append(MetricFailure(id: path, error: .schemaChanged(detail: path)))
                return
            }
            for kind in ["primary", "secondary"] {
                let field = "\(kind)_window"
                guard let value = limits[field], !(value is NSNull) else { continue }
                let id = "\(path).\(field)"
                do {
                    guard let object = value as? [String: Any] else {
                        throw FetchError.schemaChanged(detail: id)
                    }
                    let bytes = try JSONSerialization.data(withJSONObject: object)
                    let window: Window
                    do { window = try JSONDecoder().decode(Window.self, from: bytes) } catch {
                        throw schemaError(error, prefix: id)
                    }
                    guard window.used_percent.isFinite, (0...100).contains(window.used_percent) else {
                        throw FetchError.schemaChanged(detail: "\(id).used_percent")
                    }
                    if let seconds = window.limit_window_seconds, seconds <= 0 {
                        throw FetchError.schemaChanged(detail: "\(id).limit_window_seconds")
                    }
                    if let reset = window.reset_at, !reset.isFinite || reset < 0 {
                        throw FetchError.schemaChanged(detail: "\(id).reset_at")
                    }
                    let duration =
                        window.limit_window_seconds.map { seconds in
                            if seconds % 86400 == 0 { return "\(seconds / 86400)d" }
                            if seconds % 3600 == 0 { return "\(seconds / 3600)h" }
                            return "\(seconds / 60)m"
                        } ?? kind.capitalized
                    let label = path == "rate_limit" ? duration : "\(name) · \(duration)"
                    windows.append(
                        UsageWindow(
                            label: label, usedFraction: window.used_percent / 100,
                            resetsAt: window.reset_at.map(Date.init(timeIntervalSince1970:)),
                            group: path == "rate_limit" ? "primary" : path, id: id,
                            failureScopes: path == "rate_limit" ? [path] : [path, "additional_rate_limits"],
                            durationSeconds: window.limit_window_seconds.map(Double.init)))
                } catch {
                    failures.append(MetricFailure(id: id, error: (error as? FetchError) ?? .schemaChanged(detail: id)))
                }
            }
        }
        append(root["rate_limit"], path: "rate_limit", name: "Codex")
        if let extra = root["additional_rate_limits"], !(extra is NSNull) {
            if let entries = extra as? [[String: Any]] {
                for (index, entry) in entries.enumerated() {
                    guard let id = entry["metered_feature"] as? String else {
                        failures.append(
                            MetricFailure(
                                id: "additional_rate_limits.\(index)",
                                error: .schemaChanged(detail: "additional_rate_limits.\(index).metered_feature")))
                        continue
                    }
                    append(
                        entry["rate_limit"], path: "additional_rate_limits.\(id)",
                        name: entry["limit_name"] as? String ?? id)
                }
            } else {
                failures.append(
                    MetricFailure(id: "additional_rate_limits", error: .schemaChanged(detail: "additional_rate_limits"))
                )
            }
        }
        return .metrics(windows: windows, balances: [], plan: root["plan_type"] as? String, failures: failures)
    }

    private struct Auth: Decodable { let auth_mode: String?; let tokens: Tokens? }
    private struct Tokens: Decodable { let access_token: String; let account_id: String; let id_token: String }
    private struct Claims: Decodable { let sub: String }
    private struct Window: Decodable { let used_percent: Double; let limit_window_seconds: Int?; let reset_at: Double? }
}
