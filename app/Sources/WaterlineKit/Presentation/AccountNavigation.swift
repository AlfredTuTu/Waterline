import Foundation

public struct AccountNavigationRequest: Equatable, Sendable {
    public let requestID = UUID()
    public let accountID: AccountID?
    public init(accountID: AccountID? = nil) { self.accountID = accountID }
}

public enum AccountNavigationResolution: Equatable, Sendable {
    case overview, loading(AccountID), detail(AccountID), unavailable
}

public enum AccountNavigation {
    public static func decodeTarget(_ value: String?) -> AccountID? {
        guard let value, !value.isEmpty, value.utf8.count <= 256,
            !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { return nil }
        return AccountID(rawValue: value)
    }

    public static func resolve(
        _ requested: AccountID?, accounts: [AccountEntry], loading: Bool
    ) -> AccountNavigationResolution {
        guard let requested else { return .overview }
        if accounts.contains(where: { $0.account.id == requested }) { return .detail(requested) }
        return loading ? .loading(requested) : .unavailable
    }
}
