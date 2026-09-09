#if WATERLINE_VERIFICATION
    import AppKit
    import SwiftUI
    import WaterlineKit

    enum HistoryVerificationExport {
        static func run(model: AppModel) async throws {
            let provider =
                CommandLine.arguments.contains("--verification-history-empty")
                ? "codex"
                : CommandLine.arguments.contains("--verification-history-cny") ? "moonshot" : "deepseek"
            let account = AccountID(rawValue: "verification-\(provider)")
            let period: HistoryPeriod =
                CommandLine.arguments.contains("--verification-history-month") ? .month : .quarter
            var originalPreserved = true
            if CommandLine.arguments.contains("--verification-history-invalid") {
                let journal = model.verificationDirectory.appending(path: "history.jsonl")
                let original = try Data(contentsOf: journal)
                await model.retryHistoryPersistence()
                originalPreserved = try Data(contentsOf: journal) == original
                guard originalPreserved else { throw CocoaError(.fileWriteUnknown) }
            }
            let queryStart = CFAbsoluteTimeGetCurrent()
            let records = await model.balanceHistory(for: account, period: period)
            let queryDuration = CFAbsoluteTimeGetCurrent() - queryStart
            let start = CFAbsoluteTimeGetCurrent()
            let view = NSHostingView(
                rootView: HistoryWindow(model: model, account: account, period: period, observations: records)
                    .frame(width: 760, height: 560)
                    .environment(\.colorScheme, .light)
                    .background(Color.white))
            let rect = NSRect(x: 0, y: 0, width: 760, height: 560)
            let window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view
            view.frame = rect
            try await Task.sleep(for: .milliseconds(250))
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            let drawStart = CFAbsoluteTimeGetCurrent()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw CocoaError(.coderValueNotFound)
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.coderValueNotFound)
            }
            let duration = CFAbsoluteTimeGetCurrent() - start
            let imageURL = model.verificationDirectory.appending(path: "history.png")
            try png.write(to: imageURL)
            let report: [String: Any] = [
                "observations": records.count, "days": period.rawValue,
                "query_seconds": queryDuration, "settle_and_render_seconds": duration,
                "bitmap_seconds": CFAbsoluteTimeGetCurrent() - drawStart, "window_visible": window.isVisible,
                "history_failed": model.snapshot.historyFailed, "retry_error": model.historyRetryError ?? "",
                "original_preserved": originalPreserved,
                "currency": records.first?.currency ?? "none", "origin": "synthetic verification",
            ]
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: model.verificationDirectory.appending(path: "history-render.json"))
            FileHandle.standardOutput.write(Data("verification_image=\(imageURL.path)\n".utf8))
            withExtendedLifetime(window) {}
        }
    }
#endif
