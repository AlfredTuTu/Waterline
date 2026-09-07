import Foundation

/// The read-only view of the disk that discovery needs. Tests inject a synthetic home directory.
public protocol FileSystem: Sendable {
    func contents(of url: URL) throws -> Data
    func contents(of url: URL, maximumBytes: Int) throws -> Data
    func modificationDate(of url: URL) throws -> Date
    func exists(_ url: URL) -> Bool
}

public enum FileBoundaryError: Error, Equatable { case tooLarge, invalidLimit, notRegularFile }

extension FileSystem {
    public func contents(of url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes >= 0 && maximumBytes < Int.max else { throw FileBoundaryError.invalidLimit }
        let data = try contents(of: url)
        guard data.count <= maximumBytes else { throw FileBoundaryError.tooLarge }
        return data
    }
}

public struct RealFileSystem: FileSystem {
    public init() {}

    public func contents(of url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func contents(of url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes >= 0 && maximumBytes < Int.max else { throw FileBoundaryError.invalidLimit }
        let resolved = url.resolvingSymlinksInPath()
        guard try resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw FileBoundaryError.notRegularFile
        }
        let handle = try FileHandle(forReadingFrom: url)
        var data = Data()
        do {
            while data.count <= maximumBytes {
                guard let part = try handle.read(upToCount: maximumBytes + 1 - data.count), !part.isEmpty else { break }
                data.append(part)
            }
        } catch {
            try? handle.close()  // Preserve the read error if cleanup also fails.
            throw error
        }
        try handle.close()
        guard data.count <= maximumBytes else { throw FileBoundaryError.tooLarge }
        return data
    }

    public func modificationDate(of url: URL) throws -> Date {
        try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
    }

    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
