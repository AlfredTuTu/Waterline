import Foundation

/// Everything discovery may look at, injected so tests run against a synthetic machine.
public struct DiscoveryEnvironment: Sendable {
    public let home: URL
    public let processEnvironment: [String: String]
    public let fileSystem: any FileSystem
    public let keychain: any KeychainReading
    /// True only during a user-initiated connect; background discovery must never prompt.
    public let allowsUserInteraction: Bool

    public init(
        home: URL,
        processEnvironment: [String: String],
        fileSystem: any FileSystem,
        keychain: any KeychainReading,
        allowsUserInteraction: Bool
    ) {
        self.home = home
        self.processEnvironment = processEnvironment
        self.fileSystem = fileSystem
        self.keychain = keychain
        self.allowsUserInteraction = allowsUserInteraction
    }

    public static func current(allowsUserInteraction: Bool = false) -> DiscoveryEnvironment {
        DiscoveryEnvironment(
            home: FileManager.default.homeDirectoryForCurrentUser,
            processEnvironment: ProcessInfo.processInfo.environment,
            fileSystem: RealFileSystem(),
            keychain: SystemKeychain(),
            allowsUserInteraction: allowsUserInteraction
        )
    }
}
