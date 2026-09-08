#if WATERLINE_VERIFICATION
    import Foundation
    import Testing

    @testable import WaterlineKit

    struct VerificationEnvironmentTests {
        @Test func emptyOnboardingRemainsEmptyAfterRefreshAndRestart() async throws {
            let directory = VerificationEnvironment.directory(runID: UUID())
            defer { try? FileManager.default.removeItem(at: directory) }
            let dependencies = VerificationEnvironment.dependencies(directory: directory, empty: true)
            #expect(dependencies.adapters.isEmpty)
            #expect(!dependencies.environment.allowsUserInteraction)
            let engine = Engine(dependencies: dependencies)
            try await engine.start()
            try await engine.refreshAll()
            #expect(await engine.snapshot().accounts.isEmpty)
            await engine.stop()
            let restored = Engine(dependencies: dependencies)
            try await restored.start()
            #expect(await restored.snapshot().accounts.isEmpty)
            await restored.stop()
        }

        @Test func fourAccountBaselineIsIsolatedAndRestores() async throws {
            let directory = VerificationEnvironment.directory(runID: UUID())
            defer { try? FileManager.default.removeItem(at: directory) }
            let dependencies = VerificationEnvironment.dependencies(directory: directory)
            #expect(dependencies.store.url == directory.appending(path: "snapshot.json"))
            #expect(!dependencies.environment.allowsUserInteraction)
            #expect(dependencies.environment.processEnvironment.isEmpty)
            await #expect(throws: FetchError.self) {
                try await dependencies.makeHTTPClient(["api.deepseek.com"]).send(
                    HTTPRequest(url: URL(string: "https://api.deepseek.com/user/balance")!))
            }
            #expect(throws: FetchError.self) { try dependencies.environment.keychain.items(service: "unused") }
            let engine = Engine(dependencies: dependencies)
            try await engine.start()
            try await engine.refreshAll()
            let first = await engine.snapshot()
            #expect(first.accounts.count == 4)
            #expect(first.accounts.allSatisfy { $0.state.reading?.origin == .verification })
            #expect(first.accounts.filter { $0.state.reading?.usage.balances.isEmpty == true }.count == 2)
            #expect(first.accounts.filter { $0.state.reading?.usage.quotaWindows.isEmpty == true }.count == 1)
            #expect(
                first.accounts.allSatisfy {
                    $0.state.hasCurrentResponse && $0.account.id.rawValue.hasPrefix("verification-")
                })
            await engine.stop()
            let restored = Engine(dependencies: dependencies)
            try await restored.start()
            #expect(await restored.snapshot().accounts.map(\.account.id) == first.accounts.map(\.account.id))
            await restored.stop()
        }
    }
#endif
