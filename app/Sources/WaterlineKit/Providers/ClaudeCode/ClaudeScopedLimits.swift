import CryptoKit
import Foundation

extension ClaudeCodeAdapter {
    static func scopedLimits(_ value: Any?) -> (windows: [UsageWindow], failures: [MetricFailure]) {
        guard let value, !(value is NSNull) else { return ([], []) }
        guard let entries = value as? [Any] else {
            return ([], [MetricFailure(id: "limits", error: .schemaChanged(detail: "limits"))])
        }
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        for (index, value) in entries.enumerated() {
            let path = "limits.\(index)"
            var failureID = path
            do {
                guard let object = value as? [String: Any] else { throw FetchError.schemaChanged(detail: path) }
                guard object["kind"] as? String == "weekly_scoped", object["group"] as? String == "weekly" else {
                    continue
                }
                guard let scope = object["scope"] as? [String: Any], let model = scope["model"] as? [String: Any] else {
                    throw FetchError.schemaChanged(detail: "\(path).scope.model")
                }
                let modelID = try typedTrimmedString(model, key: "id", path: "\(path).scope.model.id")
                let modelName = try typedTrimmedString(
                    model, key: "display_name", path: "\(path).scope.model.display_name")
                let identity = modelID ?? modelName
                guard let identity, !identity.isEmpty else {
                    throw FetchError.schemaChanged(detail: "\(path).scope.model.id/display_name")
                }
                let normalized = identity.lowercased().split { $0.isWhitespace || $0 == "-" || $0 == "_" }.joined(
                    separator: "-")
                let normalizedName = modelName?.lowercased().split { $0.isWhitespace || $0 == "-" || $0 == "_" }.joined(
                    separator: "-")
                if normalized == "all-models" || normalized.hasSuffix("-all-models") || normalizedName == "all-models" {
                    continue
                }
                failureID =
                    "limits.weekly_scoped."
                    + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
                if failures.contains(where: { $0.id == failureID }) { continue }
                let record: ScopedLimit
                do {
                    record = try JSONDecoder().decode(
                        ScopedLimit.self, from: JSONSerialization.data(withJSONObject: object))
                } catch { throw schemaError(error, prefix: path) }
                if let percent = record.percent, !percent.isFinite || !(0...100).contains(percent) {
                    throw FetchError.schemaChanged(detail: "\(path).percent")
                }
                let reset = try date(record.resets_at, path: "\(path).resets_at")
                let window = UsageWindow(
                    label: "\(modelName.flatMap { $0.isEmpty ? nil : $0 } ?? identity) · 7d",
                    usedFraction: record.percent.map { $0 / 100 }, resetsAt: reset,
                    group: "model-weekly", id: failureID, failureScopes: ["limits", failureID],
                    durationSeconds: 7 * 86400)
                if let previous = windows.first(where: { $0.id == failureID }) {
                    guard previous == window else {
                        throw FetchError.schemaChanged(detail: "\(path) (conflicting model scope)")
                    }
                } else {
                    windows.append(window)
                }
            } catch {
                windows.removeAll { $0.id == failureID }
                if !failures.contains(where: { $0.id == failureID }) {
                    failures.append(
                        MetricFailure(id: failureID, error: (error as? FetchError) ?? .schemaChanged(detail: path)))
                }
            }
        }
        return (windows, failures)
    }

    private static func typedTrimmedString(_ dict: [String: Any], key: String, path: String) throws -> String? {
        guard let raw = dict[key], !(raw is NSNull) else { return nil }
        guard let str = raw as? String else {
            throw FetchError.schemaChanged(detail: path)
        }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ScopedLimit: Decodable {
    let percent: Double?
    let resets_at: String?
}
