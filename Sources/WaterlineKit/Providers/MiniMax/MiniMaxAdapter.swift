import Foundation

public struct MiniMaxAdapter: ProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .minimax, kind: .window, docStatus: .community,
        allowedHosts: ["www.minimaxi.com", "www.minimax.io"],
        consoleURL: URL(string: "https://platform.minimax.io/subscribe/token-plan")!,
        supportsManualKey: true,
        manualRegions: [
            ManualRegion(id: "cn", label: "MiniMax China", host: "www.minimaxi.com"),
            ManualRegion(id: "global", label: "MiniMax International", host: "www.minimax.io"),
        ],
        regionalConsoleURLs: ["cn": URL(string: "https://platform.minimaxi.com/subscribe/token-plan")!])
    public init() {}
    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] { [] }
    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        guard account.provider == .minimax, account.credential == .manual,
            let region = Self.descriptor.manualRegions.first(where: { $0.id == account.region })
        else { throw ManualKeyError.invalidRegion }
        let response = try await http.send(
            HTTPRequest(
                url: URL(string: "https://\(region.host)/v1/token_plan/remains")!,
                headers: ["Authorization": "Bearer \(secret.value)", "Content-Type": "application/json"]))
        try response.validateStatus()
        return try Self.parse(response.body)
    }

    public static func parse(_ data: Data) throws -> Usage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.schemaChanged(detail: "response")
        }
        let payload: [String: Any]
        if let nested = root["data"] {
            guard let object = nested as? [String: Any] else { throw FetchError.schemaChanged(detail: "data") }
            payload = object
        } else {
            payload = root
        }
        if let base = root["base_resp"] ?? payload["base_resp"] {
            struct Status: Decodable { let status_code: Int }
            let status: Status
            do {
                status = try JSONDecoder().decode(Status.self, from: JSONSerialization.data(withJSONObject: base))
            } catch { throw schemaError(error, prefix: "base_resp") }
            if status.status_code == 1004 { throw FetchError.unauthorized }
            guard status.status_code == 0 else { throw FetchError.transport(detail: "Token Plan request rejected") }
        }
        guard let models = payload["model_remains"] as? [Any] else {
            throw FetchError.schemaChanged(detail: "model_remains")
        }
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        var seen: Set<String> = []
        for (index, raw) in models.enumerated() {
            guard let object = raw as? [String: Any], let name = object["model_name"] as? String, !name.isEmpty else {
                failures.append(
                    MetricFailure(
                        id: "model_remains.\(index)", error: .schemaChanged(detail: "model_remains.\(index).model_name")
                    ))
                continue
            }
            for lane in ["interval", "weekly"] {
                let prefix = "current_\(lane)_"
                guard object.keys.contains(where: { $0.hasPrefix(prefix) }) else { continue }
                let id = "model_remains.\(name).\(lane)"
                do {
                    guard seen.insert(id).inserted else {
                        windows.removeAll { $0.id == id }; throw FetchError.schemaChanged(detail: "\(id) (duplicate)")
                    }
                    let status = try number(object[prefix + "status"], path: "\(id).status")
                    let percent = try number(object[prefix + "remaining_percent"], path: "\(id).remaining_percent")
                    let unquantifiedTotal =
                        status == 3 && percent == 100
                        ? try number(object[prefix + "total_count"], path: "\(id).total_count") : nil
                    if status == 3 && percent == 100 && (unquantifiedTotal == nil || unquantifiedTotal == 0) {
                        windows.append(
                            UsageWindow(
                                label: "\(name) · \(lane)", usedFraction: nil, resetsAt: nil,
                                group: "primary", id: id, failureScopes: ["model_remains"],
                                note: "Window not quantified by provider"))
                        continue
                    }
                    var used: Decimal?
                    var limit: Decimal?
                    let fraction: Double?
                    if let percent {
                        guard (0...100).contains(percent), let value = Double(((100 - percent) / 100).description)
                        else { throw FetchError.schemaChanged(detail: "\(id).remaining_percent") }
                        fraction = value
                    } else {
                        limit = try number(object[prefix + "total_count"], path: "\(id).total_count")
                        let remaining = try number(object[prefix + "usage_count"], path: "\(id).usage_count")
                        if let total = limit, let remaining {
                            guard total >= 0, remaining >= 0, remaining <= total else {
                                throw FetchError.schemaChanged(detail: "\(id).usage_count/total_count")
                            }
                            used = total - remaining
                            fraction = total > 0 ? Double(((total - remaining) / total).description) : nil
                        } else {
                            fraction = nil
                        }
                    }
                    let rawEnd = object[lane == "weekly" ? "weekly_end_time" : "end_time"]
                    let reset = try epoch(rawEnd, path: "\(id).end_time")
                    windows.append(
                        UsageWindow(
                            label: "\(name) · \(lane == "weekly" ? "Weekly" : "Current window")",
                            usedFraction: fraction,
                            resetsAt: reset, group: "primary", id: id, failureScopes: ["model_remains"], used: used,
                            limit: limit, unit: used == nil ? nil : "quota units",
                            durationSeconds: lane == "weekly" ? 7 * 86400 : nil))
                } catch {
                    failures.append(MetricFailure(id: id, error: (error as? FetchError) ?? .schemaChanged(detail: id)))
                }
            }
        }
        let plan = ["current_subscribe_title", "plan_name", "combo_title", "current_plan_title"].compactMap {
            payload[$0] as? String
        }.first
        return .metrics(windows: windows, balances: [], plan: plan, failures: failures)
    }

    private static func number(_ value: Any?, path: String) throws -> Decimal? {
        guard let value, !(value is NSNull) else { return nil }
        let string: String
        if let text = value as? String {
            string = text
        } else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            string = number.stringValue
        } else {
            throw FetchError.schemaChanged(detail: path)
        }
        guard string.range(of: #"^-?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
            let result = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")), !result.isNaN
        else { throw FetchError.schemaChanged(detail: path) }
        return result
    }

    private static func epoch(_ value: Any?, path: String) throws -> Date? {
        guard let raw = try number(value, path: path), let number = Double(raw.description) else { return nil }
        let seconds = number >= 1_000_000_000_000 ? number / 1000 : number
        guard seconds >= 1_000_000_000, seconds <= Date.distantFuture.timeIntervalSince1970 else {
            throw FetchError.schemaChanged(detail: path)
        }
        return Date(timeIntervalSince1970: seconds)
    }
}
