import Foundation

public struct XAIAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .xai, kind: .balance, docStatus: .official,
        allowedHosts: ["management-api.x.ai"], consoleURL: URL(string: "https://console.x.ai")!,
        supportsManualKey: true, requiresTeamID: true)
    public init() {}
    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] { [] }
    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .xai, account.credential == .manual, account.region == nil, let team = account.teamID,
            !team.isEmpty, team.count <= 128,
            team.unicodeScalars.allSatisfy({
                CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains(
                    $0)
            })
        else { throw ManualKeyError.invalidTeam }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://management-api.x.ai/v1/billing/teams/\(team)/prepaid/balance")!,
                headers: ["Authorization": "Bearer \(secret.value)", "Accept": "application/json"]))
        try response.validateStatus()
        return try Self.parse(response.body)
    }
    public static func parse(_ data: Data) throws -> Usage {
        struct Payload: Decodable { struct Total: Decodable { let val: String }; let total: Total }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) } catch {
            throw schemaError(error, prefix: "balance")
        }
        guard let cents = Int64(payload.total.val) else { throw FetchError.schemaChanged(detail: "total.val") }
        return .balance(
            balance: Balance(amount: -Decimal(cents) / 100, currency: "USD", gift: nil, basis: .postedLedger))
    }
}
