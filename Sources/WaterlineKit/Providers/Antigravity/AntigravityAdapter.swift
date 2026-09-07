import Foundation

public struct AntigravityAdapter: LocalProviderAdapter {
    public static let descriptor = ProviderDescriptor(
        provider: .antigravity, kind: .window, docStatus: .community, allowedHosts: [],
        consoleURL: URL(string: "https://antigravity.google")!)
    private let service: any AntigravityServiceReading
    private let executable: URL

    public init(
        service: any AntigravityServiceReading = SystemAntigravityService(),
        executable: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin/agy")
    ) {
        self.service = service
        self.executable = executable
    }

    public func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        guard environment.enabledCredentialSources.contains(.antigravityCLI) else { return [] }
        return try await service.identities(executable: executable, requestBudget: http).map { identity in
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "antigravity-\(identity.key)"), provider: .antigravity,
                    credential: .localService(name: "antigravity-cli"),
                    identity: BillingIdentity(region: "local-cli", account: identity.key)), secret: nil)
        }
    }

    public func fetchLocal(_ account: Account, requestBudget: any HTTPClient) async throws -> Usage {
        guard account.provider == .antigravity, account.credential == .localService(name: "antigravity-cli"),
            let key = account.identity?.account, account.identity?.region == "local-cli"
        else { throw FetchError.credentialMissing }
        return try await service.usage(
            identity: AntigravityAccountIdentity(key: key), executable: executable, requestBudget: requestBudget)
    }
}
