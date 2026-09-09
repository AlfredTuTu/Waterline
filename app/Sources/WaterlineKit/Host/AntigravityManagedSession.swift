import Foundation

/// Holds an empty stream open: no prompt or model request is sent to the CLI.
final class AntigravityManagedSession: @unchecked Sendable {
    private let process: Process
    private let input = Pipe()
    private let output = Pipe()
    private let lock = NSLock()
    private var ready = false
    private var stopped = false
    private var prefix = Data()
    private var idleStop: DispatchWorkItem?

    init(executable: URL, arguments: [String], directory: URL) throws {
        let process = Process()
        self.process = process
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self else { return }
            self.lock.withLock {
                guard !self.ready, !data.isEmpty else { return }
                self.prefix.append(data.prefix(max(0, 16_384 - self.prefix.count)))
                if String(decoding: self.prefix, as: UTF8.self).contains("\"event\":\"init\"") {
                    self.ready = true
                    self.prefix.removeAll()
                }
            }
        }
        do { try process.run() } catch {
            output.fileHandleForReading.readabilityHandler = nil
            throw error
        }
    }

    var isRunning: Bool { process.isRunning }
    var isReady: Bool { lock.withLock { ready } && process.isRunning }

    func renew() {
        lock.withLock {
            idleStop?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.stop() }
            idleStop = work
            DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: work)
        }
    }

    func stop() {
        let shouldStop = lock.withLock {
            guard !stopped else { return false }
            stopped = true
            idleStop?.cancel()
            idleStop = nil
            return true
        }
        guard shouldStop else { return }
        output.fileHandleForReading.readabilityHandler = nil
        try? input.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
    }

    deinit { stop() }
}
