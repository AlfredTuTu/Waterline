import Foundation
import Testing

@testable import WaterlineKit

struct OptionalSourceCLITests {
    @Test func sourceCommandsPersistAndReportPause() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let dependencies = dependencies(url, environment: ["DEEPSEEK_API_KEY": "synthetic-environment"])
        let before = await WaterlineCLI.run(["source", "check", "deepseek-env"], dependencies: dependencies)
        #expect(before.exitCode == 2 && before.error.contains("Enable"))
        let enabled = await WaterlineCLI.run(
            ["source", "enable", "deepseek-env", "--json"], dependencies: dependencies)
        #expect(enabled.exitCode == 0)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(enabled.output.utf8))
        #expect(snapshot.preferences.enabledCredentialSources == [.deepSeekEnvironment])
        #expect(snapshot.accounts.count == 1)
        // A delayed snapshot must not override the canonical consent setting in source list.
        try SnapshotStore(url: url).save(Snapshot(generatedAt: snapshot.generatedAt, accounts: snapshot.accounts))
        let listed = await WaterlineCLI.run(["source", "list"], dependencies: dependencies)
        #expect(listed.exitCode == 0 && listed.output.contains("deepseek-env  enabled"))
        #expect(!enabled.output.contains("synthetic-environment"))
        let disabled = await WaterlineCLI.run(["source", "disable", "deepseek-env"], dependencies: dependencies)
        #expect(disabled.exitCode == 0 && disabled.output.contains("[paused]"))
    }

    @Test func healthyManualAccountCannotMaskMissingEnvironmentSource() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let dependencies = dependencies(url, environment: [:])
        let manual = await WaterlineCLI.run(
            ["account", "add", "deepseek", "--stdin"], dependencies: dependencies,
            inputSecret: Secret("synthetic-manual"))
        #expect(manual.exitCode == 0)
        let source = await WaterlineCLI.run(["source", "enable", "deepseek-env", "--json"], dependencies: dependencies)
        #expect(source.exitCode == 2)
        #expect(source.error.contains("No account was found"))
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(source.output.utf8))
        #expect(snapshot.accounts.count == 1 && snapshot.accounts[0].account.credential == .manual)
    }

    @Test func unknownSourceAndKeyArgumentsFailBeforeStorage() async {
        let url = path()
        let dependencies = dependencies(url, environment: [:])
        let unknown = await WaterlineCLI.run(["source", "enable", "unknown"], dependencies: dependencies)
        let keyArgument = await WaterlineCLI.run(
            ["source", "enable", "deepseek-env", "--key", "private-value"], dependencies: dependencies)
        #expect(unknown.exitCode == 64 && keyArgument.exitCode == 64)
        #expect(!keyArgument.error.contains("private-value"))
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    private func path() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "source-cli-\(UUID())/snapshot.json")
    }
    private func dependencies(_ url: URL, environment: [String: String]) -> Engine.Dependencies {
        Engine.Dependencies(
            adapters: [DeepSeekAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: environment, fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in SourceCLIHTTP() },
            store: SnapshotStore(url: url), ownedSecrets: FakeOwnedSecrets())
    }
}

private struct SourceCLIHTTP: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.host == "api.deepseek.com")
        return HTTPResponse(
            status: 200, headers: [:], body: Data(#"{"balance_infos":[{"currency":"USD","total_balance":"20"}]}"#.utf8))
    }
}
