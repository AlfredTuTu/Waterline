import Foundation

/// Parses the official quota-summary response. Parsing alone does not establish freshness.
public enum AntigravityQuotaSummary {
    public static func parse(_ data: Data) throws -> Usage {
        guard data.count <= 1_048_576 else { throw FetchError.schemaChanged(detail: "quotaSummary.size") }
        let root: Any
        do { root = try JSONSerialization.jsonObject(with: data) } catch {
            throw FetchError.schemaChanged(detail: "quotaSummary")
        }
        guard let object = root as? [String: Any], let response = object["response"] as? [String: Any] else {
            throw FetchError.schemaChanged(detail: "response")
        }
        guard let groups = response["groups"] as? [Any] else {
            throw FetchError.schemaChanged(detail: "response.groups")
        }
        var windows: [UsageWindow] = []
        var failures: [MetricFailure] = []
        var seenBuckets: [String: Bucket] = [:]
        for (groupIndex, value) in groups.enumerated() {
            let path = "response.groups.\(groupIndex)"
            do {
                guard let group = value as? [String: Any] else { throw FetchError.schemaChanged(detail: path) }
                let name = try requiredString(group["displayName"], path: "\(path).displayName")
                guard let buckets = group["buckets"] as? [Any] else {
                    throw FetchError.schemaChanged(detail: "\(path).buckets")
                }
                for (index, value) in buckets.enumerated() {
                    let bucketPath = "\(path).buckets.\(index)"
                    var failureID = bucketPath
                    do {
                        guard let object = value as? [String: Any] else {
                            throw FetchError.schemaChanged(detail: bucketPath)
                        }
                        let id = try requiredString(object["bucketId"], path: "\(bucketPath).bucketId")
                        failureID = id
                        if failures.contains(where: { $0.id == id }) { continue }
                        let bucket: Bucket
                        do {
                            bucket = try JSONDecoder().decode(
                                Bucket.self, from: JSONSerialization.data(withJSONObject: object))
                        } catch { throw schemaError(error, prefix: bucketPath) }
                        if let fraction = bucket.remainingFraction, !fraction.isFinite || !(0...1).contains(fraction) {
                            throw FetchError.schemaChanged(detail: "\(bucketPath).remainingFraction")
                        }
                        let reset = try resetDate(bucket.resetTime, path: "\(bucketPath).resetTime")
                        let duration: TimeInterval?
                        let label: String
                        switch bucket.window {
                        case "5h":
                            duration = 5 * 3600
                            label = "\(name) · 5h"
                        case "weekly":
                            duration = 7 * 86400
                            label = "\(name) · 7d"
                        default:
                            duration = nil
                            label = bucket.displayName.map { "\(name) · \($0)" } ?? name
                        }
                        let window = UsageWindow(
                            label: label, usedFraction: bucket.remainingFraction.map { 1 - $0 }, resetsAt: reset,
                            group: name, id: id, failureScopes: ["response.groups", path, id],
                            durationSeconds: duration)
                        if let previous = windows.first(where: { $0.id == id }) {
                            // Paths are diagnostics, not provider identity, so repeated identical buckets collapse.
                            guard seenBuckets[id] == bucket, previous.label == window.label,
                                previous.group == window.group,
                                previous.usedFraction == window.usedFraction, previous.resetsAt == window.resetsAt,
                                previous.durationSeconds == window.durationSeconds
                            else {
                                throw FetchError.schemaChanged(detail: "\(bucketPath).bucketId (conflicting duplicate)")
                            }
                        } else {
                            windows.append(window)
                            seenBuckets[id] = bucket
                        }
                    } catch {
                        windows.removeAll { $0.id == failureID }
                        if !failures.contains(where: { $0.id == failureID }) {
                            failures.append(MetricFailure(id: failureID, error: failure(error, path: bucketPath)))
                        }
                    }
                }
            } catch {
                failures.append(MetricFailure(id: path, error: failure(error, path: path)))
            }
        }
        return .metrics(windows: windows, balances: [], plan: nil, failures: failures)
    }

    private static func requiredString(_ value: Any?, path: String) throws -> String {
        guard let string = value as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            string.count <= 512
        else { throw FetchError.schemaChanged(detail: path) }
        return string
    }

    private static func failure(_ error: any Error, path: String) -> FetchError {
        (error as? FetchError) ?? .schemaChanged(detail: path)
    }

    private static func resetDate(_ raw: String?, path: String) throws -> Date? {
        guard let raw else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fractional = parser.date(from: raw)
        parser.formatOptions = [.withInternetDateTime]
        guard let date = fractional ?? parser.date(from: raw) else { throw FetchError.schemaChanged(detail: path) }
        return date
    }

    private struct Bucket: Decodable, Equatable {
        let displayName: String?
        let window: String?
        let remainingFraction: Double?
        let resetTime: String?
    }
}
