import Foundation

enum AntigravitySubscription {
    static func plan(_ data: Data) throws -> String? {
        struct Tier: Decodable { let name: String? }
        struct PlanInfo: Decodable { let planName: String? }
        struct PlanStatus: Decodable { let planInfo: PlanInfo? }
        struct Status: Decodable { let userTier: Tier?; let planStatus: PlanStatus? }
        struct Response: Decodable { let userStatus: Status }
        let response: Response
        do { response = try JSONDecoder().decode(Response.self, from: data) } catch {
            throw schemaError(error, prefix: "antigravity.subscription")
        }
        let name = response.userStatus.userTier?.name ?? response.userStatus.planStatus?.planInfo?.planName
        guard let name else { return nil }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.utf8.count <= 128,
            !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { throw FetchError.schemaChanged(detail: "userStatus.subscription.name") }
        return name
    }
}
