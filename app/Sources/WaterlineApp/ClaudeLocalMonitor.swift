import Darwin
import Foundation

/// Owns one filesystem event source; no periodic scans or network activity.
final class ClaudeLocalMonitor: @unchecked Sendable {
    private let source: DispatchSourceFileSystemObject

    init(directory: URL, changed: @escaping @Sendable () -> Void) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let descriptor = open(directory.path, O_EVTONLY | O_CLOEXEC)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoPermission) }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete], queue: .global(qos: .utility))
        source.setEventHandler(handler: changed)
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
    }

    deinit { source.cancel() }
}
