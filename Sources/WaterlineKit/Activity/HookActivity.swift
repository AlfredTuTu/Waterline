import CryptoKit
import Foundation

public struct HookActivityEvent: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case began = "UserPromptSubmit"
        case stopped = "Stop"
        case failed = "StopFailure"
        case ended = "SessionEnd"
    }
    public let session: String
    public let kind: Kind
    public let receivedAt: Date
    public static let notificationName = "io.github.alfredtutu.waterline.hook.v1"

    public static func parse(_ data: Data, now: Date) throws -> Self {
        guard data.count <= 1_048_576 else { throw HookActivityError.invalidInput }
        struct Input: Decodable {
            let session_id: String
            let hook_event_name: Kind
        }
        let input: Input
        do { input = try JSONDecoder().decode(Input.self, from: data) } catch { throw HookActivityError.invalidInput }
        guard !input.session_id.isEmpty, input.session_id.utf8.count <= 256,
            !input.session_id.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw HookActivityError.invalidInput }
        let digest = SHA256.hash(data: Data(("waterline-claude-hook-v1:" + input.session_id).utf8))
        return Self(
            session: digest.map { String(format: "%02x", $0) }.joined(),
            kind: input.hook_event_name, receivedAt: now)
    }
}

public enum HookActivityError: Error, Equatable { case invalidInput, invalidSettings, hooksDisabled }

public struct HookActivityState: Sendable {
    private var sessions: [String: HookActivityEvent] = [:]
    public init() {}
    public mutating func receive(_ event: HookActivityEvent, now: Date) {
        sessions = sessions.filter { now.timeIntervalSince($0.value.receivedAt) <= 600 }
        guard event.session.count == 64, event.session.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
            now.timeIntervalSince(event.receivedAt) >= -5,
            now.timeIntervalSince(event.receivedAt) <= 600,
            sessions[event.session].map({ $0.receivedAt < event.receivedAt }) ?? true
        else { return }
        guard sessions[event.session] != nil || sessions.count < 256 else { return }
        sessions[event.session] = event
    }
    public func activeCount(now: Date) -> Int {
        sessions.values.filter { $0.kind == .began && now.timeIntervalSince($0.receivedAt) < 600 }.count
    }
}
