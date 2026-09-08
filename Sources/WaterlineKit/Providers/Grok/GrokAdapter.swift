import CryptoKit
import Foundation

public struct GrokAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .grok, kind: .window, docStatus: .official,
        allowedHosts: ["cli-chat-proxy.grok.com"],
        consoleURL: URL(string: "https://grok.com/?_s=usage")!)
    public init() {}

    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        let url = environment.home.appending(path: ".grok/auth.json")
        guard environment.fileSystem.exists(url) else { return [] }
        let data = try environment.fileSystem.contents(of: url, maximumBytes: 1_048_576)
        struct Auth: Decodable {
            let auth_mode: String
            let key: String
            let user_id: String
            let principal_type: String?
            let oidc_issuer: String?
            let oidc_client_id: String?
        }
        guard let records = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.schemaChanged(detail: "grok.auth")
        }
        let namespaces = records.keys.filter { $0.hasPrefix("https://auth.x.ai::") }.sorted()
        guard namespaces.count <= 1 else { throw FetchError.schemaChanged(detail: "grok.auth (multiple profiles)") }
        guard let namespace = namespaces.first else { return [] }
        let auth: Auth
        do {
            auth = try JSONDecoder().decode(
                Auth.self, from: JSONSerialization.data(withJSONObject: records[namespace]!))
        } catch { throw schemaError(error, prefix: "grok.auth.profile") }
        guard auth.auth_mode == "oidc", auth.principal_type == "User",
            auth.oidc_issuer == "https://auth.x.ai", let client = auth.oidc_client_id,
            namespace == "https://auth.x.ai::" + client
        else { return [] }
        guard !auth.key.isEmpty, auth.key.utf8.count <= 16_384,
            auth.key.utf8.allSatisfy({ (33...126).contains($0) }),
            !auth.user_id.isEmpty, auth.user_id.utf8.count <= 256,
            auth.user_id.utf8.allSatisfy({ (33...126).contains($0) })
        else { throw FetchError.credentialMissing }
        let digest = SHA256.hash(data: Data(("grok-consumer:" + auth.user_id).utf8))
            .map { String(format: "%02x", $0) }.joined()
        let account = Account(
            id: AccountID(rawValue: "grok-" + digest), provider: .grok,
            credential: .file(path: url.path),
            identity: BillingIdentity(region: "grok.com", account: digest, subject: auth.user_id))
        return [Discovered(account: account, secret: Secret(auth.key))]
    }

    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .grok, account.identity?.region == "grok.com",
            let subject = account.identity?.subject, !subject.isEmpty,
            subject.utf8.allSatisfy({ (33...126).contains($0) })
        else { throw FetchError.credentialMissing }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://cli-chat-proxy.grok.com/v1/billing?format=credits")!,
                headers: [
                    "Authorization": "Bearer \(secret.value)", "X-XAI-Token-Auth": "xai-grok-cli",
                    "x-userid": subject, "Accept": "application/json",
                    "User-Agent": "Waterline/\(WaterlineVersion.current)",
                ]))
        try response.validateStatus()
        return try Self.parse(response.body)
    }

    public static func parse(_ data: Data) throws -> Usage {
        struct Period: Decodable { let type: String?; let start: String?; let end: String? }
        struct Config: Decodable {
            let creditUsagePercent: Double?; let currentPeriod: Period?; let isUnifiedBillingUser: Bool?
        }
        struct Response: Decodable { let config: Config?; let subscriptionTier: String? }
        let response: Response
        do { response = try JSONDecoder().decode(Response.self, from: data) } catch {
            throw schemaError(error, prefix: "grok.billing")
        }
        guard let config = response.config else { throw FetchError.schemaChanged(detail: "config") }
        if let value = config.creditUsagePercent, !value.isFinite || !(0...100).contains(value) {
            throw FetchError.schemaChanged(detail: "config.creditUsagePercent")
        }
        func date(_ value: String?, path: String) throws -> Date? {
            guard let value else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = formatter.date(from: value) { return parsed }
            formatter.formatOptions = [.withInternetDateTime]
            guard let parsed = formatter.date(from: value) else { throw FetchError.schemaChanged(detail: path) }
            return parsed
        }
        let start = try date(config.currentPeriod?.start, path: "config.currentPeriod.start")
        let end = try date(config.currentPeriod?.end, path: "config.currentPeriod.end")
        if let start, let end, end <= start { throw FetchError.schemaChanged(detail: "config.currentPeriod") }
        let label: String
        let duration: TimeInterval?
        switch config.currentPeriod?.type {
        case "USAGE_PERIOD_TYPE_WEEKLY": label = "7d"; duration = 604_800
        case "USAGE_PERIOD_TYPE_MONTHLY":
            label = "Monthly"; duration = start.flatMap { a in end.map { $0.timeIntervalSince(a) } }
        default: label = "Grok"; duration = nil
        }
        var percentage = config.creditUsagePercent
        // Match the official client only for an identified unified billing window.
        // Empty/legacy/partial envelopes must not become a fabricated zero.
        if percentage == nil, config.isUnifiedBillingUser == true, start != nil, end != nil,
            ["USAGE_PERIOD_TYPE_WEEKLY", "USAGE_PERIOD_TYPE_MONTHLY"].contains(config.currentPeriod?.type ?? ""),
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let raw = root["config"] as? [String: Any], raw["creditUsagePercent"] == nil
        {
            percentage = 0
        }
        return .windows(
            windows: [
                UsageWindow(
                    label: label, usedFraction: percentage.map { $0 / 100 },
                    resetsAt: end, id: "grok.subscription", durationSeconds: duration)
            ],
            plan: response.subscriptionTier)
    }
}
