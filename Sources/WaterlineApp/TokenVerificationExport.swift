#if WATERLINE_VERIFICATION
    import AppKit
    import SwiftUI
    import WaterlineKit

    enum TokenVerificationExport {
        static func run(model: AppModel) async throws {
            let restoring = CommandLine.arguments.contains("--verification-token-restore")
            var importedCount = 0
            var duplicateCount = 0
            if !restoring {
                let date = ISO8601DateFormatter()
                date.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let now = Date()
                var data = Data(
                    (#"{"type":"session_meta","payload":{"id":"bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb","source":"cli","model_provider":"openai"}}"#
                        + "\n"
                        + #"{"type":"turn_context","payload":{"model":"gpt-6-astra"}}"# + "\n").utf8)
                let encoder = JSONEncoder()
                func counts(_ factor: Int64) throws -> String {
                    String(
                        decoding: try encoder.encode(
                            CodexTokenCounters(
                                input: factor * 100, cachedInput: factor * 80,
                                output: factor * 10, reasoningOutput: factor * 4, total: factor * 110)), as: UTF8.self)
                }
                for index in 0..<1000 {
                    if index % 250 == 0 && CommandLine.arguments.contains("--verification-token-mixed-price") {
                        let model = ["gpt-6-astra", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"][index / 250]
                        data.append(Data("{\"type\":\"turn_context\",\"payload\":{\"model\":\"\(model)\"}}\n".utf8))
                    }
                    if (index == 990 && CommandLine.arguments.contains("--verification-token-partial-price"))
                        || (index == 0 && CommandLine.arguments.contains("--verification-token-unpriced"))
                    {
                        data.append(
                            Data((#"{"type":"turn_context","payload":{"model":"unlisted-fixture"}}"# + "\n").utf8))
                    }
                    let timestamp = date.string(from: now.addingTimeInterval(-Double(999 - index) * 3600))
                    let line =
                        "{\"type\":\"event_msg\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":\(try counts(Int64(index+1))),\"last_token_usage\":\(try counts(1))}}}\n"
                    data.append(Data(line.utf8))
                }
                let input = model.verificationDirectory.appending(path: "synthetic-token-log.jsonl")
                try data.write(to: input)
                let imported = try await model.importCodexLog(input)
                importedCount = imported.addedSamples
                let duplicate = try await model.importCodexLog(input)
                duplicateCount = duplicate.addedSamples
                guard imported.addedSamples == 1000, duplicate.addedSamples == 0 else {
                    throw TokenLedgerError.incompatible
                }
            }
            let sources = try await model.tokenHistory()
            guard !sources.isEmpty else { throw TokenLedgerError.incompatible }
            let selectedDays = !restoring && CommandLine.arguments.contains("--verification-token-week") ? 7 : 30
            let recent = sources.flatMap(\.samples).filter {
                $0.observedAt >= Date().addingTimeInterval(-Double(selectedDays) * 86400)
            }
            let valuation = TokenReferenceValuation.summarize(recent)
            let view = NSHostingView(
                rootView: content(model: model, sources: sources, days: selectedDays, restoring: restoring)
                    .frame(width: 800, height: 580).environment(\.colorScheme, .light).background(Color.white))
            let rect = NSRect(x: 0, y: 0, width: 800, height: 580)
            let window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view; view.frame = rect
            try await Task.sleep(for: .milliseconds(250))
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw CocoaError(.coderValueNotFound)
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.coderValueNotFound)
            }
            let url = model.verificationDirectory.appending(path: "tokens.png"); try png.write(to: url)
            let result: [String: Any] = [
                "imported": importedCount, "duplicate_added": duplicateCount,
                "restore_only": restoring, "total_saved_records": sources.flatMap(\.samples).count,
                "loaded_sources": sources.count,
                "priced_records": valuation.pricedRecords, "selected_records": valuation.totalRecords,
                "reference_usd": valuation.amount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "unpriced",
                "quote_id": TokenReferenceValuation.quoteID, "window_visible": window.isVisible,
                "origin": "synthetic verification",
            ]
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                .write(to: model.verificationDirectory.appending(path: "tokens-render.json"))
            FileHandle.standardOutput.write(Data("verification_image=\(url.path)\n".utf8))
            withExtendedLifetime(window) {}
        }
        @ViewBuilder
        private static func content(model: AppModel, sources: [TokenImport], days: Int, restoring: Bool) -> some View {
            if restoring {
                TokenHistoryWindow(model: model)
            } else {
                TokenHistoryWindow(model: model, sources: sources, days: days)
            }
        }
    }
#endif
