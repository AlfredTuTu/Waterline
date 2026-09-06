import Foundation

/// Owns discovery, fetching and freshness. The app and the CLI are both clients of this actor.
public actor Engine {
    public struct Dependencies: Sendable {
        public var adapters: [any ProviderAdapter]
        public var environment: DiscoveryEnvironment
        public var makeHTTPClient: @Sendable (Set<String>) -> any HTTPClient
        public var store: SnapshotStore
        public var now: @Sendable () -> Date

        public init(
            adapters: [any ProviderAdapter] = Registry.adapters,
            environment: DiscoveryEnvironment = .current(),
            makeHTTPClient: @escaping @Sendable (Set<String>) -> any HTTPClient = {
                URLSessionHTTPClient(allowedHosts: $0)
            },
            store: SnapshotStore = .default(),
            now: @escaping @Sendable () -> Date = Date.init
        ) {
            self.adapters = adapters
            self.environment = environment
            self.makeHTTPClient = makeHTTPClient
            self.store = store
            self.now = now
        }
    }

    private let dependencies: Dependencies
    private let adapters: [Provider: any ProviderAdapter]
    private var accounts: [Account] = []
    private var secrets: [AccountID: Secret] = [:]
    private var states: [AccountID: AccountState] = [:]
    private var subscribers: [UUID: AsyncStream<Snapshot>.Continuation] = [:]

    public init(dependencies: Dependencies = Dependencies()) {
        self.dependencies = dependencies
        adapters = Dictionary(
            uniqueKeysWithValues: dependencies.adapters.map { (type(of: $0).descriptor.provider, $0) }
        )
    }

    /// Discover accounts and show the last snapshot immediately; refreshing is scheduled by the caller.
    public func start() async throws {
        let previous = try dependencies.store.load()?.accounts ?? []
        let previousStates = Dictionary(uniqueKeysWithValues: previous.map { ($0.account.id, $0.state) })
        for adapter in dependencies.adapters {
            for discovered in try await adapter.discover(in: dependencies.environment) {
                accounts.append(discovered.account)
                secrets[discovered.account.id] = discovered.secret
                states[discovered.account.id] = previousStates[discovered.account.id] ?? .pending
            }
        }
        try publish()
    }

    /// Fetch every account once and persist the result.
    public func refreshAll() async throws {
        for account in accounts {
            states[account.id] = await fetch(account)
        }
        try publish()
    }

    public func snapshot() -> Snapshot {
        let entries = accounts.map { AccountEntry(account: $0, state: states[$0.id]!) }
        return Snapshot(generatedAt: dependencies.now(), accounts: entries)
    }

    public var updates: AsyncStream<Snapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(id) }
            }
        }
    }

    private func fetch(_ account: Account) async -> AccountState {
        let previous = states[account.id]?.reading
        guard let secret = secrets[account.id] else { return degraded(previous, .keychainLocked) }
        let adapter = adapters[account.provider]!
        do {
            let http = dependencies.makeHTTPClient(type(of: adapter).descriptor.allowedHosts)
            let usage = try await adapter.fetch(account, secret: secret, http: http)
            return .fresh(reading: Reading(usage: usage, fetchedAt: dependencies.now()))
        } catch let error as FetchError {
            return degraded(previous, error)
        } catch {
            return degraded(previous, .transport(detail: String(describing: error)))
        }
    }

    private func degraded(_ previous: Reading?, _ error: FetchError) -> AccountState {
        previous.map { .stale(reading: $0, error: error) } ?? .unavailable(error: error)
    }

    private func publish() throws {
        let snapshot = snapshot()
        try dependencies.store.save(snapshot)
        for continuation in subscribers.values {
            continuation.yield(snapshot)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}
