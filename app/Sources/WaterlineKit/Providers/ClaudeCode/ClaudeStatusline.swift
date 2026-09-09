import Foundation

/// A CLI observation, not a server fetch. The payload has neither account identity nor provider observation time.
public struct ClaudeStatuslineReading: Sendable, Equatable {
    public let sessionID: UUID
    public let version: String
    public let apiDurationMilliseconds: Double?
    public let quotas: [ClaudeStatuslineQuota]
}

public struct ClaudeStatuslineQuota: Codable, Sendable, Equatable {
    public let id: String
    public let usedFraction: Double
    public let resetsAt: Date
}

public enum ClaudeStatusline {
    public static func parse(_ data: Data) throws -> ClaudeStatuslineReading {
        guard data.count <= 1_048_576 else { throw FetchError.schemaChanged(detail: "claude.statusline.size") }
        struct Bucket: Decodable {
            let used_percentage: Double
            let resets_at: Double
        }
        struct Limits: Decodable { let five_hour: Bucket?; let seven_day: Bucket? }
        struct Cost: Decodable { let total_api_duration_ms: Double? }
        struct Payload: Decodable {
            let session_id: String
            let version: String
            let cost: Cost?
            let rate_limits: Limits?
        }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: data) } catch {
            throw schemaError(error, prefix: "claude.statusline")
        }
        guard let session = UUID(uuidString: payload.session_id) else {
            throw FetchError.schemaChanged(detail: "claude.statusline.session_id")
        }
        guard !payload.version.isEmpty, payload.version.utf8.count <= 128,
            !payload.version.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw FetchError.schemaChanged(detail: "claude.statusline.version") }
        if let duration = payload.cost?.total_api_duration_ms, !duration.isFinite || duration < 0 {
            throw FetchError.schemaChanged(detail: "claude.statusline.cost.total_api_duration_ms")
        }
        var quotas: [ClaudeStatuslineQuota] = []
        for (id, bucket) in [
            ("five_hour", payload.rate_limits?.five_hour), ("seven_day", payload.rate_limits?.seven_day),
        ] {
            guard let bucket else { continue }
            guard bucket.used_percentage.isFinite, (0...100).contains(bucket.used_percentage) else {
                throw FetchError.schemaChanged(detail: "claude.statusline.rate_limits.\(id).used_percentage")
            }
            guard bucket.resets_at.isFinite, (0...253_402_300_799).contains(bucket.resets_at) else {
                throw FetchError.schemaChanged(detail: "claude.statusline.rate_limits.\(id).resets_at")
            }
            quotas.append(
                ClaudeStatuslineQuota(
                    id: id, usedFraction: bucket.used_percentage / 100,
                    resetsAt: Date(timeIntervalSince1970: bucket.resets_at)))
        }
        return ClaudeStatuslineReading(
            sessionID: session, version: payload.version,
            apiDurationMilliseconds: payload.cost?.total_api_duration_ms, quotas: quotas)
    }
}
