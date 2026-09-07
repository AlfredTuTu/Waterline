import Foundation
import Observation
import UserNotifications
import WaterlineKit

@Observable
final class QuotaNotifications: NSObject, UNUserNotificationCenterDelegate {
    var openAccounts: ((AccountID?) -> Void)? {
        didSet {
            if let openAccounts, let pendingOpen {
                self.pendingOpen = nil
                openAccounts(pendingOpen.accountID)
            }
        }
    }
    private var pendingOpen: AccountNavigationRequest?
    private(set) var enabled = false
    private(set) var changing = false
    private(set) var message: String?
    private(set) var activity: String?
    private(set) var activityAccountID: AccountID?
    private let store: ThresholdAlertStore
    private let notificationsAllowed: Bool
    private var ledger: ThresholdAlerts?
    private var activityTask: Task<Void, Never>?

    init(
        storeURL: URL = SnapshotStore.default().url.deletingLastPathComponent().appending(path: "alerts.json"),
        notificationsAllowed: Bool = true
    ) {
        store = ThresholdAlertStore(url: storeURL)
        self.notificationsAllowed = notificationsAllowed
        super.init()
        if notificationsAllowed { UNUserNotificationCenter.current().delegate = self }
        do {
            var ledger = try store.load()
            if !notificationsAllowed { ledger.enabled = false }
            self.ledger = ledger
            enabled = ledger.enabled
        } catch { message = "Could not read alert settings. Existing settings were preserved." }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let target = AccountNavigation.decodeTarget(
            response.notification.request.content.userInfo["waterlineAccountID"] as? String)
        await MainActor.run {
            if let openAccounts = self.openAccounts {
                openAccounts(target)
            } else {
                self.pendingOpen = AccountNavigationRequest(accountID: target)
            }
        }
    }

    func setEnabled(_ enabled: Bool) async {
        guard notificationsAllowed else { return }
        guard !changing, ledger != nil else { return }
        changing = true
        defer { changing = false }
        do {
            if enabled {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [
                    .alert, .sound,
                ])
                guard granted else {
                    message = "Allow Waterline notifications in macOS System Settings."
                    return
                }
            }
            guard var ledger = self.ledger else { return }
            ledger.enabled = enabled
            try store.save(ledger)
            self.ledger = ledger
            self.enabled = enabled
            message = nil
            if !enabled {
                activityTask?.cancel()
                activity = nil
                activityAccountID = nil
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        } catch { message = "Could not update notifications. Check system permissions and try again." }
    }

    func receive(_ snapshot: Snapshot) {
        guard snapshot.lastAttemptAt != nil, !snapshot.storageFailed, var next = ledger else { return }
        let alerts = next.evaluate(snapshot)
        guard next != ledger else { return }
        do {
            // Reserve the attempt durably before handing it to macOS; a crash cannot duplicate it.
            try store.save(next)
            ledger = next
        } catch {
            message = "Could not save alert history. Notifications are paused until storage recovers."
            return
        }
        for alert in alerts {
            Task {
                let center = UNUserNotificationCenter.current()
                let settings = await center.notificationSettings()
                guard enabled else { return }
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    message = "Notifications are disabled in macOS System Settings."
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.userInfo = ["waterlineAccountID": alert.accountID.rawValue]
                content.body = AppText.format(
                    "%@ reached a usage threshold.", alert.metricNames.joined(separator: ", "))
                content.sound = .default
                do {
                    try await center.add(
                        UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
                    guard enabled else { return }
                    activityTask?.cancel()
                    activity = AppText.format("%@: usage alert", alert.title)
                    activityAccountID = alert.accountID
                    activityTask = Task {
                        do { try await Task.sleep(for: .seconds(3)) } catch { return }
                        activity = nil
                        activityAccountID = nil
                    }
                } catch { message = "macOS could not show a usage notification." }
            }
        }
    }
}
