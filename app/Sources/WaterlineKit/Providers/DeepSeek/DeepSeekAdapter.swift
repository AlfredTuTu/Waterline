import Foundation

/// Balance adapter with manual keys and explicitly enabled process-environment discovery.
public struct DeepSeekAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .deepseek, kind: .balance, docStatus: .official,
        allowedHosts: ["api.deepseek.com"], consoleURL: URL(string: "https://platform.deepseek.com/usage")!,
        supportsManualKey: true)
    public init() {}

    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        var accounts: [Discovered] = []
        if environment.enabledCredentialSources.contains(.deepSeekEnvironment),
            let value = environment.processEnvironment["DEEPSEEK_API_KEY"]
        {
            accounts.append(
                Self.credential(
                    value, reference: .env(name: "DEEPSEEK_API_KEY", sourceFile: "process"),
                    field: "environment.DEEPSEEK_API_KEY"))
        }
        if environment.enabledCredentialSources.contains(.deepSeekClaudeSettings) {
            accounts += discoverClaudeSettings(in: environment)
        }
        if environment.enabledCredentialSources.contains(.deepSeekOpenCode) {
            accounts += discoverOpenCode(in: environment)
        }
        return accounts
    }

    static func credential(_ value: String, reference: CredentialRef, field: String) -> Discovered {
        let account = Account(provider: .deepseek, credential: reference)
        guard !value.isEmpty, value.utf8.count <= 8192, !value.contains(where: \.isWhitespace),
            !value.contains(where: { "$`\\".contains($0) }),
            !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            return Discovered(account: account, secret: nil, connectionError: .schemaChanged(detail: field))
        }
        return Discovered(account: account, secret: Secret(value))
    }

    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .deepseek,
            account.identity == nil || account.identity?.region == "api.deepseek.com"
        else { throw FetchError.credentialMissing }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://api.deepseek.com/user/balance")!,
                headers: ["Authorization": "Bearer \(secret.value)", "Accept": "application/json"]))
        try response.validateStatus()
        return try Self.parse(response.body)
    }

    public static func parse(_ data: Data) throws -> Usage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = root["balance_infos"] as? [Any]
        else { throw FetchError.schemaChanged(detail: "balance_infos") }
        var balances: [Balance] = []
        var failures: [MetricFailure] = []
        var seen: Set<String> = []
        for (index, value) in entries.enumerated() {
            let path = "balance_infos.\(index)"
            guard let object = value as? [String: Any], let currency = object["currency"] as? String,
                ["CNY", "USD"].contains(currency)
            else {
                failures.append(MetricFailure(id: path, error: .schemaChanged(detail: "\(path).currency")))
                continue
            }
            let id = "balance.\(currency)"
            guard seen.insert(currency).inserted else {
                balances.removeAll { $0.currency == currency }
                failures.append(MetricFailure(id: id, error: .schemaChanged(detail: "\(path).currency (duplicate)")))
                continue
            }
            do {
                let amount = try money(object["total_balance"], path: "\(path).total_balance")
                var gift: Decimal?
                if let value = object["granted_balance"], !(value is NSNull) {
                    do { gift = try money(value, path: "\(path).granted_balance") } catch {
                        failures.append(
                            MetricFailure(id: "\(id).gift", error: .schemaChanged(detail: "\(path).granted_balance")))
                    }
                }
                balances.append(Balance(amount: amount, currency: currency, gift: gift))
            } catch {
                failures.append(MetricFailure(id: id, error: (error as? FetchError) ?? .schemaChanged(detail: path)))
            }
        }
        return .metrics(windows: [], balances: balances, plan: nil, failures: failures)
    }

    private static func money(_ value: Any?, path: String) throws -> Decimal {
        guard let text = value as? String,
            text.range(of: #"^[+]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
            let amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !amount.isNaN, amount >= 0
        else {
            throw FetchError.schemaChanged(detail: path)
        }
        return amount
    }
}
