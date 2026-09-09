import AppKit
import Network
import UserNotifications
import WaterlineKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private let networkMonitor = NWPathMonitor()
    private var networkAvailable: Bool?
    private var panel: NotchPanel?
    private var duplicateLaunch = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard !model.isVerification, let identifier = Bundle.main.bundleIdentifier else { return }
        let current = NSRunningApplication.current
        let currentDate = current.launchDate ?? .distantFuture
        let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { application in
                guard application.processIdentifier != current.processIdentifier, !application.isTerminated else {
                    return false
                }
                let date = application.launchDate ?? .distantPast
                return date < currentDate
                    || (date == currentDate && application.processIdentifier < current.processIdentifier)
            }
            .min { $0.processIdentifier < $1.processIdentifier }
        if let existing {
            duplicateLaunch = true
            existing.activate()
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !duplicateLaunch else { return }
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
        SoftwareUpdates.shared.start()
        if !model.isVerification {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            Task { await LegacyIntegrationCleanup.shared.run() }
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let previous = self.networkAvailable
                self.networkAvailable = available
                if previous == false && available { self.model.recoverConnection() }
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "Waterline.network"))
        screenChanged()
        #if WATERLINE_VERIFICATION
            if CommandLine.arguments.contains("--verification-render")
                || CommandLine.arguments.contains("--verification-history-render")
                || CommandLine.arguments.contains("--verification-token-render")
            {
                exportVerificationView()
            }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        networkMonitor.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func willSleep() { model.suspendForSleep() }
    @objc private func didWake() { model.recoverConnection() }

    func showAccounts() { panel?.showAccounts() }

    @objc private func screenChanged() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let geometry = NotchGeometry.compute(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryTopRightWidth: screen.auxiliaryTopRightArea?.width
        )
        if let panel { panel.updateGeometry(geometry); return }
        let panel = NotchPanel(geometry: geometry, model: model)
        if !CommandLine.arguments.contains("--verification-render")
            && !CommandLine.arguments.contains("--verification-history-render")
            && !CommandLine.arguments.contains("--verification-token-render")
        {
            panel.orderFrontRegardless()
        }
        self.panel = panel
    }

    #if WATERLINE_VERIFICATION
        private func exportVerificationView() {
            Task {
                for _ in 0..<100 {
                    if model.loaded
                        && model.snapshot.accounts.count
                            == (CommandLine.arguments.contains("--verification-empty") ? 0 : 4)
                        && model.snapshot.accounts.allSatisfy({ $0.state.hasCurrentResponse }) && !model.refreshing
                    {
                        do {
                            if CommandLine.arguments.contains("--verification-history-render") {
                                try await HistoryVerificationExport.run(model: model)
                                NSApplication.shared.terminate(nil)
                                return
                            }
                            guard let panel else { throw CocoaError(.coderValueNotFound) }
                            if CommandLine.arguments.contains("--verification-language-cycle") {
                                let original = AppLocalization.shared.language
                                defer { AppLocalization.shared.select(original) }
                                for language in [AppLanguage.english, .simplifiedChinese] {
                                    AppLocalization.shared.select(language)
                                    guard AppLocalization.shared.language == language else {
                                        throw CocoaError(.coderValueNotFound)
                                    }
                                    try await panel.exportVerificationImage(
                                        to: model.verificationDirectory.appending(
                                            path: "language-\(language.rawValue).png"))
                                }
                                FileHandle.standardOutput.write(Data("verification_language_cycle=complete\n".utf8))
                                NSApplication.shared.terminate(nil)
                                return
                            }
                            if CommandLine.arguments.contains("--verification-long-labels") {
                                for (index, entry) in model.snapshot.accounts.enumerated() {
                                    await model.rename(
                                        entry,
                                        label:
                                            "Account \(index + 1) · Research workspace with a deliberately long descriptive name"
                                    )
                                }
                            }
                            let url = model.verificationDirectory.appending(path: "island.png")
                            try await panel.exportVerificationImage(to: url)
                            FileHandle.standardOutput.write(Data("verification_image=\(url.path)\n".utf8))
                            NSApplication.shared.terminate(nil)
                        } catch {
                            FileHandle.standardError.write(Data("Verification view export failed.\n".utf8))
                            exit(1)
                        }
                        return
                    }
                    do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                }
                FileHandle.standardError.write(Data("Verification data did not become ready.\n".utf8))
                exit(1)
            }
        }
    #endif
}
