import Foundation

/// The read-only view of the disk that discovery needs. Tests inject a synthetic home directory.
public protocol FileSystem: Sendable {
    func contents(of url: URL) throws -> Data
    func modificationDate(of url: URL) throws -> Date
    func exists(_ url: URL) -> Bool
}

public struct RealFileSystem: FileSystem {
    public init() {}

    public func contents(of url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func modificationDate(of url: URL) throws -> Date {
        try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
    }

    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
