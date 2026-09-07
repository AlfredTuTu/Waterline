#if WATERLINE_VERIFICATION
    import Foundation

    /// Compiled only into the separately identified verification app, never the distributed app.
    public enum VerificationEnvironment {
        public static func directory(runID: UUID) -> URL {
            FileManager.default.temporaryDirectory.appending(path: "WaterlineVerification/\(runID.uuidString)")
        }

        public static func seedLongHistory(directory: URL, now: Date = Date(), incompatible: Bool = false) throws {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let journal = directory.appending(path: "history.jsonl")
            guard !FileManager.default.fileExists(atPath: journal.path) else { return }
            var records: [BalanceObservation] = []
            for index in 1..<25920 where !(12000..<12048).contains(index) {
                records.append(
                    BalanceObservation(
                        accountID: AccountID(rawValue: "verification-deepseek"), currency: "USD",
                        amount: Decimal(10000 - index % 800) / 100,
                        observedAt: now.addingTimeInterval(-Double(index) * 300)))
            }
            for index in 1..<1000 {
                records.append(
                    BalanceObservation(
                        accountID: AccountID(rawValue: "verification-moonshot"), currency: "CNY",
                        amount: Decimal(20000 - index) / 100,
                        observedAt: now.addingTimeInterval(-Double(index) * 3600)))
            }
            try HistoryStore(url: journal).compact(records)
            if incompatible {
                let file = try FileHandle(forWritingTo: journal)
                defer { try? file.close() }
                try file.seekToEnd()
                try file.write(contentsOf: Data("invalid complete record\n".utf8))
            }
        }

        public static func dependencies(directory: URL) -> Engine.Dependencies {
            Engine.Dependencies(
                adapters: [FixtureCodex(), FixtureClaude(), FixtureBalance(), FixtureBoth()],
                environment: DiscoveryEnvironment(
                    home: directory.appending(path: "home"), processEnvironment: [:],
                    fileSystem: NoFiles(), keychain: NoKeychain(), allowsUserInteraction: false),
                makeHTTPClient: { _ in NoNetwork() },
                store: SnapshotStore(url: directory.appending(path: "snapshot.json")),
                ownedSecrets: NoOwnedSecrets(), observationOrigin: .verification)
        }
    }

    private func account(_ provider: Provider) -> [Discovered] {
        [
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "verification-\(provider.rawValue)"), provider: provider,
                    credential: .file(path: "/verification/\(provider.rawValue)"),
                    region: provider == .moonshot ? "cn" : nil), secret: Secret("verification-only"))
        ]
    }
    private func fixtureDescriptor(_ provider: Provider, _ kind: QuotaKind) -> ProviderDescriptor {
        ProviderDescriptor(
            provider: provider, kind: kind, docStatus: .community, allowedHosts: [],
            consoleURL: URL(string: "https://invalid.example")!)
    }
    private func window(_ fraction: Double) -> UsageWindow {
        UsageWindow(
            label: "Fixture 5h", usedFraction: fraction, resetsAt: Date().addingTimeInterval(18000),
            id: "fixture-window")
    }
    private struct FixtureCodex: ProviderAdapter {
        static let descriptor = fixtureDescriptor(Provider.codex, .window)
        func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
            account(.codex)
        }
        func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
            .windows(windows: [window(0.23)], plan: "Fixture")
        }
    }
    private struct FixtureClaude: ProviderAdapter {
        static let descriptor = fixtureDescriptor(Provider.claudeCode, .window)
        func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
            account(.claudeCode)
        }
        func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
            if CommandLine.arguments.contains("--verification-unsupported") {
                return .unsupported(reason: "This account does not expose a verified quota query.")
            }
            if CommandLine.arguments.contains("--verification-component-failure") {
                return .metrics(
                    windows: [window(0.44)], balances: [], plan: "Fixture",
                    failures: [MetricFailure(id: "seven_day", error: .schemaChanged(detail: "seven_day.utilization"))])
            }
            if CommandLine.arguments.contains("--verification-expired-secondary") {
                return .windows(
                    windows: [
                        window(0.44),
                        UsageWindow(
                            label: "Fixture earlier", usedFraction: 0.1,
                            resetsAt: Date().addingTimeInterval(-60), id: "fixture-earlier"),
                    ], plan: "Fixture")
            }
            return .windows(windows: [window(0.44)], plan: "Fixture")
        }
    }
    private struct FixtureBalance: ProviderAdapter {
        static let descriptor = fixtureDescriptor(Provider.deepseek, .balance)
        func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
            account(.deepseek)
        }
        func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
            .balance(balance: Balance(amount: 40, currency: "USD", gift: nil))
        }
    }
    private struct FixtureBoth: ProviderAdapter {
        static let descriptor = fixtureDescriptor(Provider.moonshot, .both)
        func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
            account(.moonshot)
        }
        func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
            .both(windows: [window(0.35)], balance: Balance(amount: 200, currency: "CNY", gift: nil))
        }
    }
    private struct NoFiles: FileSystem {
        func exists(_ url: URL) -> Bool { false }
        func contents(of url: URL) throws -> Data { throw FetchError.credentialMissing }
        func modificationDate(of url: URL) throws -> Date { throw FetchError.credentialMissing }
    }
    private struct NoKeychain: KeychainReading {
        func items(service: String) throws -> [KeychainItem] { throw FetchError.keychainLocked }
        func secret(for item: KeychainItem, allowsUserInteraction: Bool) throws -> Secret {
            throw FetchError.keychainLocked
        }
    }
    private struct NoOwnedSecrets: OwnedSecretStoring {
        func read(_ id: AccountID, interactive: Bool) throws -> Secret { throw FetchError.credentialMissing }
        func save(_ secret: Secret, for id: AccountID) throws { throw FetchError.credentialMissing }
        func delete(_ id: AccountID) throws { throw FetchError.credentialMissing }
    }
    private struct NoNetwork: HTTPClient {
        func send(_ request: HTTPRequest) async throws -> HTTPResponse {
            throw FetchError.transport(detail: "Verification mode blocks all network requests")
        }
    }
#endif
