import Foundation

public struct MoonshotAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .moonshot, kind: .balance, docStatus: .official,
        allowedHosts: ["api.moonshot.cn", "api.moonshot.ai"], consoleURL: URL(string: "https://platform.kimi.ai")!,
        supportsManualKey: true,
        manualRegions: [
            ManualRegion(id: "cn", label: "China · CNY", host: "api.moonshot.cn"),
            ManualRegion(id: "global", label: "International · USD", host: "api.moonshot.ai"),
        ],
        regionalConsoleURLs: [
            "cn": URL(string: "https://platform.kimi.com")!, "global": URL(string: "https://platform.kimi.ai")!,
        ])
    public init() {}
    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] { [] }

    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .moonshot,
            let region = Self.descriptor.manualRegions.first(where: { $0.id == account.region }),
            account.identity == nil || account.identity?.region == region.host
        else { throw ManualKeyError.invalidRegion }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://\(region.host)/v1/users/me/balance")!,
                headers: ["Authorization": "Bearer \(secret.value)", "Accept": "application/json"]))
        try response.validateStatus()
        return try Self.parse(response.body, region: region.id)
    }

    public static func parse(_ data: Data, region: String) throws -> Usage {
        guard region == "cn" || region == "global" else { throw ManualKeyError.invalidRegion }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) } catch {
            throw schemaError(error, prefix: "balance")
        }
        guard payload.code == 0, payload.status else { throw FetchError.transport(detail: "Balance request rejected") }
        guard !payload.data.available_balance.isNaN else {
            throw FetchError.schemaChanged(detail: "data.available_balance")
        }
        var failures: [MetricFailure] = []
        let currency = region == "cn" ? "CNY" : "USD"
        var gift = payload.data.voucher_balance
        if payload.data.invalidVoucher || gift?.isNaN == true || (gift.map { $0 < 0 } ?? false) {
            gift = nil
            failures.append(
                MetricFailure(id: "balance.\(currency).gift", error: .schemaChanged(detail: "data.voucher_balance")))
        }
        return .metrics(
            windows: [], balances: [Balance(amount: payload.data.available_balance, currency: currency, gift: gift)],
            plan: nil, failures: failures)
    }

    private struct Payload: Decodable {
        let code: Int
        let status: Bool
        let data: Values
    }
    private struct Values: Decodable {
        let available_balance: Decimal
        let voucher_balance: Decimal?
        let invalidVoucher: Bool
        enum CodingKeys: String, CodingKey { case available_balance, voucher_balance }
        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            available_balance = try values.decode(Decimal.self, forKey: .available_balance)
            do {
                voucher_balance = try values.decodeIfPresent(Decimal.self, forKey: .voucher_balance)
                invalidVoucher = false
            } catch { voucher_balance = nil; invalidVoucher = true }
        }
    }
}
