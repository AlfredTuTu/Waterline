import AppKit
import ServiceManagement
import SwiftUI

struct LoginItemSettings: View {
    @State private var status = SMAppService.mainApp.status
    @State private var changing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { status == .enabled || status == .requiresApproval },
                    set: { enabled in Task { await setEnabled(enabled) } }
                )
            ).disabled(changing)
            if changing {
                ProgressView("Updating…").controlSize(.small)
            } else {
                Text(LocalizedStringKey(statusDescription)).font(.caption).foregroundStyle(.secondary)
            }
            if status == .requiresApproval || errorMessage != nil {
                Button("Open Login Items Settings") { SMAppService.openSystemSettingsLoginItems() }
            }
            if let errorMessage {
                Text(LocalizedStringKey(errorMessage)).font(.caption).foregroundStyle(.red)
            }
        }
        .onAppear { status = SMAppService.mainApp.status }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            status = SMAppService.mainApp.status
        }
    }

    private var statusDescription: String {
        switch status {
        case .enabled: "Waterline will open automatically when you log in."
        case .notRegistered: "Open Waterline manually when you need it."
        case .requiresApproval: "Allow Waterline in System Settings to finish enabling launch at login."
        case .notFound: "macOS could not locate the app. Install Waterline and try again."
        @unknown default: "Login item status is unavailable."
        }
    }

    private func setEnabled(_ enabled: Bool) async {
        guard !changing else { return }
        changing = true
        errorMessage = nil
        let service = SMAppService.mainApp
        defer {
            status = service.status
            changing = false
        }
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval { try service.register() }
            } else if service.status != .notRegistered {
                try await service.unregister()
            }
        } catch {
            errorMessage = "Could not change launch at login. Check Login Items in System Settings and try again."
        }
    }
}
