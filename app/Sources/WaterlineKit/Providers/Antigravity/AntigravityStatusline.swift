import Foundation

/// Official CLI status-line payload, not a live fetch. The source supplies no observation timestamp.
public struct AntigravityStatuslineReading: Sendable {
    public let accountSubject: String
    public let plan: String?
    public let windows: [AntigravityStatuslineQuota]
}

/// Deliberately not a UsageWindow: receiving this payload cannot establish quota freshness.
public struct AntigravityStatuslineQuota: Sendable {
    public let id: String
    public let usedFraction: Double?
    public let resetsAt: Date?
}

public enum AntigravityStatusline {
    public static func parse(_ data: Data) throws -> AntigravityStatuslineReading {
        guard data.count <= 1_048_576 else { throw FetchError.schemaChanged(detail: "statusline.size") }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) } catch {
            throw schemaError(error, prefix: "statusline")
        }
        guard payload.product == "antigravity" else { throw FetchError.schemaChanged(detail: "product") }
        let subject = payload.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty, subject.count <= 512 else { throw FetchError.schemaChanged(detail: "email") }
        var windows: [AntigravityStatuslineQuota] = []
        for id in (payload.quota ?? [:]).keys.sorted() {
            guard !id.isEmpty, id.count <= 256, let bucket = payload.quota?[id] else {
                throw FetchError.schemaChanged(detail: "quota.bucket")
            }
            if let remaining = bucket.remainingFraction, !remaining.isFinite || !(0...1).contains(remaining) {
                throw FetchError.schemaChanged(detail: "quota.\(id).remaining_fraction")
            }
            let reset: Date?
            if let raw = bucket.resetTime {
                let parser = ISO8601DateFormatter()
                parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let fractional = parser.date(from: raw)
                parser.formatOptions = [.withInternetDateTime]
                guard let date = fractional ?? parser.date(from: raw) else {
                    throw FetchError.schemaChanged(detail: "quota.\(id).reset_time")
                }
                reset = date
            } else {
                reset = nil
            }
            windows.append(
                AntigravityStatuslineQuota(
                    id: id, usedFraction: bucket.remainingFraction.map { 1 - $0 }, resetsAt: reset))
        }
        return AntigravityStatuslineReading(accountSubject: subject, plan: payload.planTier, windows: windows)
    }

    private struct Payload: Decodable {
        let product: String
        let email: String
        let quota: [String: Bucket]?
        let planTier: String?
        enum CodingKeys: String, CodingKey { case product, email, quota; case planTier = "plan_tier" }
    }
    private struct Bucket: Decodable {
        let remainingFraction: Double?
        let resetTime: String?
        enum CodingKeys: String, CodingKey {
            case remainingFraction = "remaining_fraction"
            case resetTime = "reset_time"
        }
    }
}
