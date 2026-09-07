import Foundation

/// Validates one JSON object per line without materializing payload strings or arrays.
/// Only the root type and immediate payload type are retained for selective decoding.
final class JSONLRecordScanner {
    struct Record {
        let start: Int
        let end: Int
        let type: String
        let payloadType: String?
        let payloadIsObject: Bool
    }
    enum ScanError: Error { case incomplete }
    private enum Role { case root, payload, other }
    private let file: FileHandle
    private let length: Int
    private var buffer: [UInt8] = []
    private var index = 0
    private(set) var offset = 0
    private var rootType: String?
    private var payloadType: String?
    private var payloadIsObject = false
    private var sawNewline = false
    private var retainedKeyCount = 0
    private var retainedKeyBytes = 0

    init(file: FileHandle, length: Int) { self.file = file; self.length = length }

    func next() throws -> Record? {
        while let byte = try peek(), [9, 10, 13, 32].contains(byte) { _ = try take() }
        guard try peek() != nil else { return nil }
        sawNewline = false
        do { return try scanRecord() } catch TokenLogError.invalidRecord {
            // JSONL records are committed by their newline. Defer an unfinished tail to the next read.
            guard !sawNewline else { throw TokenLogError.invalidRecord }
            while let byte = try peek() {
                _ = try take()
                if byte == 10 { throw TokenLogError.invalidRecord }
            }
            throw ScanError.incomplete
        }
    }

    private func scanRecord() throws -> Record {
        let start = offset
        rootType = nil; payloadType = nil; payloadIsObject = false
        guard try peek() == 123 else { throw TokenLogError.invalidRecord }
        try object(role: .root, depth: 0)
        let end = offset
        try whitespace()
        guard let terminator = try peek() else { throw ScanError.incomplete }
        guard terminator == 10, let type = rootType else { throw TokenLogError.invalidRecord }
        _ = try take()
        return Record(start: start, end: end, type: type, payloadType: payloadType, payloadIsObject: payloadIsObject)
    }

    func data(for record: Record) throws -> Data {
        guard record.end - record.start <= 4 * 1024 * 1024 else { throw TokenLogError.tooLarge }
        let resume = try file.offset()
        try file.seek(toOffset: UInt64(record.start))
        var data = Data()
        while data.count < record.end - record.start {
            guard let chunk = try file.read(upToCount: record.end - record.start - data.count), !chunk.isEmpty else {
                throw TokenLogError.invalidRecord
            }
            data.append(chunk)
        }
        try file.seek(toOffset: resume)
        return data
    }

    private func peek() throws -> UInt8? {
        if index == buffer.count {
            try Task.checkCancellation()
            guard offset < length else { return nil }
            guard let data = try file.read(upToCount: min(65536, length - offset)), !data.isEmpty else {
                throw TokenLogError.invalidRecord
            }
            buffer = Array(data); index = 0
        }
        return buffer[index]
    }
    private func take() throws -> UInt8 {
        guard let byte = try peek() else { throw ScanError.incomplete }
        if byte == 10 { sawNewline = true }
        index += 1; offset += 1; return byte
    }
    private func expect(_ byte: UInt8) throws {
        guard try take() == byte else { throw TokenLogError.invalidRecord }
    }
    private func whitespace() throws {
        while let byte = try peek(), [9, 13, 32].contains(byte) { _ = try take() }
    }
    private func value(role: Role, depth: Int) throws {
        guard depth <= 128 else { throw TokenLogError.tooLarge }
        try whitespace()
        guard let byte = try peek() else { throw ScanError.incomplete }
        switch byte {
        case 123: try object(role: role, depth: depth)
        case 91:
            _ = try take(); try whitespace()
            if try peek() == 93 { _ = try take(); return }
            while true {
                try value(role: .other, depth: depth + 1); try whitespace()
                let separator = try take()
                if separator == 93 { return }
                guard separator == 44 else { throw TokenLogError.invalidRecord }
            }
        case 34: _ = try string(capture: false)
        case 116: for byte in "true".utf8 { try expect(byte) }
        case 102: for byte in "false".utf8 { try expect(byte) }
        case 110: for byte in "null".utf8 { try expect(byte) }
        case 45, 48...57: try number()
        default: throw TokenLogError.invalidRecord
        }
    }
    private func object(role: Role, depth: Int) throws {
        guard depth <= 128 else { throw TokenLogError.tooLarge }
        try expect(123); try whitespace()
        if try peek() == 125 { _ = try take(); return }
        var keys = Set<String>()
        var localKeyBytes = 0
        defer { retainedKeyCount -= keys.count; retainedKeyBytes -= localKeyBytes }
        while true {
            try whitespace()
            let key = try string(capture: true)
            guard keys.insert(key).inserted else { throw TokenLogError.invalidRecord }
            retainedKeyCount += 1
            retainedKeyBytes += key.utf8.count
            localKeyBytes += key.utf8.count
            guard retainedKeyCount <= 10000, retainedKeyBytes <= 1_048_576 else { throw TokenLogError.tooLarge }
            try whitespace(); try expect(58); try whitespace()
            if role == .root && key == "type" {
                rootType = try string(capture: true)
            } else if role == .payload && key == "type", try peek() == 34 {
                payloadType = try string(capture: true)
            } else {
                let nested: Role = role == .root && key == "payload" ? .payload : .other
                if nested == .payload { payloadIsObject = try peek() == 123 }
                try value(role: nested, depth: depth + 1)
            }
            try whitespace()
            let separator = try take()
            if separator == 125 { return }
            guard separator == 44 else { throw TokenLogError.invalidRecord }
        }
    }
    private func string(capture: Bool) throws -> String {
        try expect(34)
        var raw: [UInt8] = capture ? [34] : []
        func keep(_ byte: UInt8) throws {
            if capture {
                guard raw.count < 4096 else { throw TokenLogError.tooLarge }
                raw.append(byte)
            }
        }
        while true {
            let byte = try take(); try keep(byte)
            if byte == 34 {
                return capture ? try JSONDecoder().decode(String.self, from: Data(raw)) : ""
            }
            guard byte >= 32 else { throw TokenLogError.invalidRecord }
            if byte == 92 {
                let escape = try take(); try keep(escape)
                if escape == 117 {
                    var code = 0
                    for _ in 0..<4 { let byte = try take(); try keep(byte); code = code * 16 + (try hex(byte)) }
                    if (0xD800...0xDBFF).contains(code) {
                        for byte: UInt8 in [92, 117] { try expect(byte); try keep(byte) }
                        var low = 0
                        for _ in 0..<4 { let byte = try take(); try keep(byte); low = low * 16 + (try hex(byte)) }
                        guard (0xDC00...0xDFFF).contains(low) else { throw TokenLogError.invalidRecord }
                    } else if (0xDC00...0xDFFF).contains(code) {
                        throw TokenLogError.invalidRecord
                    }
                } else if ![34, 92, 47, 98, 102, 110, 114, 116].contains(escape) {
                    throw TokenLogError.invalidRecord
                }
            } else if byte >= 128 {
                let remaining: Int
                let range: ClosedRange<UInt8>
                switch byte {
                case 0xC2...0xDF: remaining = 1; range = 0x80...0xBF
                case 0xE0: remaining = 2; range = 0xA0...0xBF
                case 0xE1...0xEC, 0xEE...0xEF: remaining = 2; range = 0x80...0xBF
                case 0xED: remaining = 2; range = 0x80...0x9F
                case 0xF0: remaining = 3; range = 0x90...0xBF
                case 0xF1...0xF3: remaining = 3; range = 0x80...0xBF
                case 0xF4: remaining = 3; range = 0x80...0x8F
                default: throw TokenLogError.invalidRecord
                }
                for index in 0..<remaining {
                    let next = try take(); try keep(next)
                    guard (index == 0 ? range : 0x80...0xBF).contains(next) else { throw TokenLogError.invalidRecord }
                }
            }
        }
    }
    private func hex(_ byte: UInt8) throws -> Int {
        switch byte {
        case 48...57: Int(byte - 48)
        case 65...70: Int(byte - 55)
        case 97...102: Int(byte - 87)
        default: throw TokenLogError.invalidRecord
        }
    }
    private func digits() throws {
        guard let first = try peek() else { throw ScanError.incomplete }
        guard (48...57).contains(first) else { throw TokenLogError.invalidRecord }
        while let byte = try peek(), (48...57).contains(byte) { _ = try take() }
    }
    private func number() throws {
        if try peek() == 45 { _ = try take() }
        if try peek() == 48 { _ = try take() } else { try digits() }
        if try peek() == 46 { _ = try take(); try digits() }
        if let byte = try peek(), byte == 101 || byte == 69 {
            _ = try take()
            if let sign = try peek(), sign == 43 || sign == 45 { _ = try take() }
            try digits()
        }
    }
}
