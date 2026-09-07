import Foundation
import Testing

@testable import WaterlineKit

struct JSONLRecordScannerTests {
    private let header =
        #"{"type":"session_meta","payload":{"id":"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa","source":"cli"}}"# + "\n"
    private func read(_ record: Data) throws -> CodexTokenLogReport {
        let url = FileManager.default.temporaryDirectory.appending(path: "stream-json-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        try (Data(header.utf8) + record).write(to: url)
        return try CodexTokenLog.read(url)
    }

    @Test func largeCompactionIsValidatedWithoutTheTokenRecordBudget() throws {
        let payload = String(repeating: "x", count: 7_300_000)
        let record = "{\"payload\":{\"replacement_history\":[{\"text\":\"\(payload)\"}]},\"type\":\"compacted\"}\n"
        let report = try read(Data(record.utf8))
        #expect(report.samples.isEmpty && report.coverageGaps == 0 && !report.incompleteTail)
    }

    @Test func unicodeAndEscapedStringsAcrossBufferBoundariesRemainValid() throws {
        let value = String(repeating: "x", count: 65500) + "你好🌊"
        let object: [String: Any] = ["type": "compacted", "payload": ["text": value, "escaped": "\"\\\n"]]
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(10)
        #expect(try !read(data).incompleteTail)
        #expect(try !read(Data(#"{"type":"compacted","payload":"\uD83C\uDF0A"}"#.utf8) + Data([10])).incompleteTail)
    }

    @Test func unicodeContinuationBytesActuallyCrossTheReadBoundary() throws {
        let prefix = #"{"type":"compacted","payload":""#
        for split in 1...3 {
            let padding = 65536 - header.utf8.count - prefix.utf8.count - split
            let record = prefix + String(repeating: "x", count: padding) + "🌊" + "\"}\n"
            #expect(try !read(Data(record.utf8)).incompleteTail)
        }
    }

    @Test func relevantRecordsStillHaveTheOriginalDecodeBudget() throws {
        let record =
            #"{"type":"turn_context","payload":{"model":"synthetic","extra":""#
            + String(repeating: "x", count: 4 * 1024 * 1024) + "\"}}\n"
        #expect(throws: (any Error).self) { try read(Data(record.utf8)) }
    }

    @Test func malformedCompleteRecordsAndDuplicateKeysAreRejectedEvenWhenIgnored() throws {
        for text in [
            #"{"type":"compacted","payload":[1,]}"#,
            #"{"type":"compacted","payload":01}"#,
            #"{"type":"compacted","payload":1e+}"#,
            #"{"type":"compacted","payload":"\uD800"}"#,
            #"{"type":"compacted","\u0074ype":"session_meta","payload":{}}"#,
            #"{"type":"compacted","payload":{"a":1,"a":2}}"#,
        ] {
            #expect(throws: (any Error).self) { try read(Data((text + "\n").utf8)) }
        }
        var invalidUTF8 = Data(#"{"type":"compacted","payload":""#.utf8)
        invalidUTF8.append(contentsOf: [0xC0, 0x80]); invalidUTF8.append(Data("\"}\n".utf8))
        #expect(throws: (any Error).self) { try read(invalidUTF8) }
    }

    @Test func unfinishedTailIsDeferredButNewlineCommitsItsError() throws {
        for tail in ["{unfinished", "{\"x\":-", "{\"x\":1e+", "{\"x\":\"unterminated"] {
            #expect(try read(Data(tail.utf8)).incompleteTail)
            #expect(throws: (any Error).self) { try read(Data((tail + "\n").utf8)) }
        }
    }
}
