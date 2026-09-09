import Foundation
import Testing

@testable import WaterlineKit

struct CLITests {
    private func dependencies(
        _ url: URL, adapters: [any ProviderAdapter] = [GoodAdapter(gate: nil)]
    ) -> Engine.Dependencies {
        .init(
            adapters: adapters,
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in UnusedHTTP() },
            store: SnapshotStore(url: url))
    }

    @Test func refreshJsonAndAccountMutationRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-cli-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let deps = dependencies(url)
        let refreshed = await WaterlineCLI.run(["refresh", "--provider", "deepseek", "--json"], dependencies: deps)
        #expect(refreshed.exitCode == 0)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(refreshed.output.utf8))
        let id = try #require(snapshot.accounts.first?.account.id.rawValue)
        let disabled = await WaterlineCLI.run(["account", "disable", id], dependencies: deps)
        #expect(disabled.exitCode == 0)
        #expect(disabled.output.contains("[paused]"))
        let reread = await WaterlineCLI.run(["accounts", "--json"], dependencies: deps)
        #expect(reread.exitCode == 0)
        #expect(
            try SnapshotStore.decoder.decode(Snapshot.self, from: Data(reread.output.utf8)).accounts.first?.preferences
                .enabled == false)
    }

    @Test func discoveryFailureHasNonzeroStatus() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-cli-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let result = await WaterlineCLI.run(
            ["refresh", "--json"],
            dependencies: dependencies(url, adapters: [FailingDiscovery(), GoodAdapter(gate: nil)]))
        #expect(result.exitCode == 2)
        #expect(!result.output.isEmpty)
        #expect(!result.error.isEmpty)
    }

    @Test func historyWriteFailureReturnsDataWithNonzeroStatus() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-cli-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent().appending(path: "history.jsonl"), withIntermediateDirectories: true)
        let result = await WaterlineCLI.run(["refresh", "--json"], dependencies: dependencies(url))
        #expect(result.exitCode == 1)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8))
        #expect(snapshot.historyFailed)
        #expect(snapshot.accounts.first?.state.reading?.usage.balances.first?.amount == 20)
    }

    @Test func unknownFlagIsRejectedBeforeDiscovery() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-cli-\(UUID())/snapshot.json")
        let result = await WaterlineCLI.run(["refresh", "--unrecognised"], dependencies: dependencies(url))
        #expect(result.exitCode == 64)
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    @Test func busyWriterReportsUseApp() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-cli-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let deps = dependencies(url)
        let subject = Engine(dependencies: deps)
        try await subject.start()
        let result = await WaterlineCLI.run(["refresh"], dependencies: deps)
        #expect(result.exitCode == 3)
        #expect(result.error.contains("Use the app"))
        await subject.stop()
    }
}
