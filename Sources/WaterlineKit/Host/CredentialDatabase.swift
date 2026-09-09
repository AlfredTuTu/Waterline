import Foundation
import SQLite3

public protocol CredentialDatabaseReading: Sendable {
    func cursorAccessToken(at url: URL) throws -> Secret?
}

public struct UnavailableCredentialDatabase: CredentialDatabaseReading {
    public init() {}
    public func cursorAccessToken(at url: URL) throws -> Secret? { throw FetchError.credentialMissing }
}

public struct SystemCredentialDatabase: CredentialDatabaseReading {
    public init() {}

    public func cursorAccessToken(at url: URL) throws -> Secret? {
        var database: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        defer { if let database { sqlite3_close(database) } }
        guard result == SQLITE_OK, let database else {
            throw FetchError.transport(detail: "Could not open Cursor login database")
        }
        sqlite3_busy_timeout(database, 250)
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let query = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1"
        let prepared = sqlite3_prepare_v2(database, query, -1, &statement, nil)
        if prepared == SQLITE_BUSY || prepared == SQLITE_LOCKED {
            throw FetchError.transport(detail: "Cursor login database is busy or unreadable")
        }
        guard prepared == SQLITE_OK else {
            throw FetchError.schemaChanged(detail: "Cursor.ItemTable")
        }
        switch sqlite3_step(statement) {
        case SQLITE_DONE: return nil
        case SQLITE_ROW:
            let size = sqlite3_column_bytes(statement, 0)
            guard size > 0, size <= 16384,
                sqlite3_column_type(statement, 0) == SQLITE_TEXT,
                let bytes = sqlite3_column_text(statement, 0),
                let value = String(data: Data(bytes: bytes, count: Int(size)), encoding: .utf8)
            else { throw FetchError.schemaChanged(detail: "Cursor.accessToken") }
            return Secret(value)
        default: throw FetchError.transport(detail: "Cursor login database is busy or unreadable")
        }
    }
}
