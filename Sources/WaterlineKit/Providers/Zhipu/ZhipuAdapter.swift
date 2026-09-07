import Foundation

public struct ZhipuAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .zhipu, kind: .window, docStatus: .community,
        allowedHosts: ["open.bigmodel.cn", "api.z.ai"],
        consoleURL: URL(string: "https://z.ai/manage-apikey/coding-plan/personal/my-plan")!,
        supportsManualKey: true,
        manualRegions: [
            ManualRegion(id: "cn", label: "BigModel China", host: "open.bigmodel.cn"),
            ManualRegion(id: "global", label: "Z.ai International", host: "api.z.ai"),
        ],
        regionalConsoleURLs: ["cn": URL(string: "https://bigmodel.cn/coding-plan/personal/usage")!])
    public init() {}
    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] { [] }
    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .zhipu, account.credential == .manual,
            let region = Self.descriptor.manualRegions.first(where: { $0.id == account.region }),
            account.identity == nil || account.identity?.region == region.host
        else { throw ManualKeyError.invalidRegion }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://\(region.host)/api/monitor/usage/quota/limit")!,
                headers: ["Authorization": "Bearer \(secret.value)", "Accept": "application/json"]))
        try response.validateStatus()
        return try Self.parse(response.body)
    }

    public static func parse(_ data: Data) throws -> Usage {
        struct Status: Decodable { let code: Int; let success: Bool }
        let status: Status
        do { status = try JSONDecoder().decode(Status.self, from: data) } catch {
            throw schemaError(error, prefix: "response")
        }
        guard status.success, status.code == 200 else { throw FetchError.transport(detail: "Quota request rejected") }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = root["data"] as? [String: Any], let entries = payload["limits"] as? [Any]
        else { throw FetchError.schemaChanged(detail: "data.limits") }
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        var seen: Set<String> = []
        for (index, value) in entries.enumerated() {
            let path = "data.limits.\(index)"
            guard let object = value as? [String: Any], let type = object["type"] as? String else {
                failures.append(MetricFailure(id: "limits.\(index)", error: .schemaChanged(detail: "\(path).type")))
                continue
            }
            guard ["TOKENS_LIMIT", "CREDIT_LIMIT", "TIME_LIMIT"].contains(type) else { continue }
            var id = "limits.\(index)"
            do {
                let limit: Limit
                do {
                    let data = try JSONSerialization.data(withJSONObject: object)
                    let identity = try JSONDecoder().decode(LimitIdentity.self, from: data)
                    id = "\(type).\(identity.unit).\(identity.number)"
                    limit = try JSONDecoder().decode(Limit.self, from: data)
                } catch { throw schemaError(error, prefix: path) }
                guard seen.insert(id).inserted else {
                    windows.removeAll { $0.id == id }
                    throw FetchError.schemaChanged(detail: "\(path) (duplicate)")
                }
                guard limit.percentage.isFinite, (0...100).contains(limit.percentage) else {
                    throw FetchError.schemaChanged(detail: "\(path).percentage")
                }
                for (field, value) in [
                    ("usage", limit.usage), ("currentValue", limit.currentValue), ("remaining", limit.remaining),
                ] {
                    if let value, value.isNaN || value < 0 {
                        throw FetchError.schemaChanged(detail: "\(path).\(field)")
                    }
                }
                var fraction = limit.percentage / 100
                var used = limit.currentValue
                if let total = limit.usage, total > 0 {
                    if used == nil, let remaining = limit.remaining { used = total - remaining }
                    if let value = used {
                        guard !value.isNaN, value >= 0, value <= total,
                            let derived = Double((value / total).description), derived.isFinite
                        else {
                            throw FetchError.schemaChanged(detail: "\(path).currentValue/usage")
                        }
                        fraction = derived
                    }
                }
                var duration: String?
                var durationSeconds: TimeInterval?
                if let multiplier = [1: 1440, 3: 60, 5: 1, 6: 10080][limit.unit], limit.number > 0 {
                    let (minutes, overflow) = limit.number.multipliedReportingOverflow(by: multiplier)
                    guard !overflow else { throw FetchError.schemaChanged(detail: "\(path).number") }
                    durationSeconds = Double(minutes) * 60
                    duration =
                        minutes % 1440 == 0
                        ? "\(minutes / 1440)d" : minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes)m"
                }
                let reset: Date?
                if let milliseconds = limit.nextResetTime {
                    let seconds = Double(milliseconds) / 1000
                    guard seconds >= 0, seconds <= Date.distantFuture.timeIntervalSince1970 else {
                        throw FetchError.schemaChanged(detail: "\(path).nextResetTime")
                    }
                    reset = Date(timeIntervalSince1970: seconds)
                } else {
                    reset = nil
                }
                windows.append(
                    UsageWindow(
                        label: type == "TIME_LIMIT" ? "MCP" : duration ?? "Coding quota",
                        usedFraction: fraction, resetsAt: reset, group: type == "TIME_LIMIT" ? "mcp" : "primary",
                        id: id,
                        failureScopes: ["limits"], used: used, limit: limit.usage, unit: "quota units",
                        durationSeconds: durationSeconds))
            } catch {
                failures.append(MetricFailure(id: id, error: (error as? FetchError) ?? .schemaChanged(detail: path)))
            }
        }
        let plan = ["planName", "plan", "plan_type", "packageName", "level"].compactMap { payload[$0] as? String }.first
        return .metrics(windows: windows, balances: [], plan: plan, failures: failures)
    }
    private struct LimitIdentity: Decodable { let unit: Int; let number: Int }

    private struct Limit: Decodable {
        let unit: Int
        let number: Int
        let percentage: Double
        let usage: Decimal?
        let currentValue: Decimal?
        let remaining: Decimal?
        let nextResetTime: Int64?
    }
}
