import Foundation

extension Engine {
    public func tokenHistory() throws -> [TokenImport] {
        guard started else { throw SettingsError.engineNotStarted }
        return try tokenStore.load()
    }

    public func importCodexLog(_ url: URL) async throws -> TokenImportResult {
        guard started, !suspended else { throw SettingsError.engineNotStarted }
        try Task.checkCancellation()
        guard tokenImport == nil else { throw TokenLedgerError.busy }
        let id = UUID(), session = lifecycle
        let work = Task.detached(priority: .utility) { try CodexTokenLog.read(url) }
        tokenImport = work; tokenImportID = id
        defer { if tokenImportID == id { tokenImport = nil; tokenImportID = nil } }
        let report = try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
        try Task.checkCancellation()
        guard started, lifecycle == session else { throw CancellationError() }
        return try tokenStore.merge(report, now: dependencies.now())
    }
}
