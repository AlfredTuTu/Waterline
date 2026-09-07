import Combine
import Sparkle
import SwiftUI
import WaterlineKit

final class SoftwareUpdates: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = SoftwareUpdates()
    @Published private(set) var available = false
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var failedToStart = false
    private var controller: SPUStandardUpdaterController?
    private var observations = Set<AnyCancellable>()

    func start() {
        #if WATERLINE_VERIFICATION
            return
        #else
            guard controller == nil, let info = Bundle.main.infoDictionary,
                SoftwareUpdatePolicy.isConfigured(info)
            else { return }
            let controller = SPUStandardUpdaterController(
                startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
            self.controller = controller
            do {
                try controller.updater.start()
                available = true
            } catch {
                failedToStart = true
                return
            }
            controller.updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    MainActor.assumeIsolated { self?.canCheck = value }
                }.store(in: &observations)
            controller.updater.publisher(for: \.automaticallyChecksForUpdates)
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    MainActor.assumeIsolated { self?.automaticChecks = value }
                }.store(in: &observations)
        #endif
    }

    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }

    func updater(
        _ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem,
        updateCheck: SPUUpdateCheck
    ) throws {
        guard SoftwareUpdatePolicy.permitsArchive(item.fileURL) else {
            throw NSError(
                domain: "Waterline.SoftwareUpdates", code: 1,
                userInfo: [NSLocalizedDescriptionKey: AppText.text("The update download address is not supported.")])
        }
    }

    func check() {
        guard available, canCheck else { return }
        controller?.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard available else { return }
        controller?.updater.automaticallyChecksForUpdates = enabled
    }
}

struct SoftwareUpdateSettings: View {
    @ObservedObject private var updates = SoftwareUpdates.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Check for updates…") { updates.check() }
                .disabled(!updates.canCheck)
            if updates.available {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { updates.automaticChecks },
                        set: { updates.setAutomaticChecks($0) }))
                Text("Update checks contact GitHub. Installation requires your confirmation.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(
                    LocalizedStringKey(
                        updates.failedToStart
                            ? "Could not start updates. Reopen Waterline and try again."
                            : "Updates are unavailable in this development build.")
                ).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
