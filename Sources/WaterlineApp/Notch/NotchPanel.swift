import AppKit
import SwiftUI
import WaterlineKit

final class NotchPanel: NSPanel {
    private var geometry: NotchGeometry
    private let model: AppModel
    private let layout: IslandLayout
    private var expanded: Bool {
        get { layout.expanded }
        set { layout.expanded = newValue }
    }
    private var hoverTask: Task<Void, Never>?
    private var trackingMenus: Set<ObjectIdentifier> = []
    override var canBecomeKey: Bool { expanded }

    override func cancelOperation(_ sender: Any?) {
        if expanded || layout.preview { closeAccounts() } else { super.cancelOperation(sender) }
    }

    override func becomeKey() {
        super.becomeKey()
        layout.keyboardActive = true
    }

    override func resignKey() {
        super.resignKey()
        layout.keyboardActive = false
        scheduleCollapse()
    }

    init(geometry: NotchGeometry, model: AppModel) {
        self.geometry = geometry
        self.model = model
        self.layout = IslandLayout(geometry: geometry)
        super.init(
            contentRect: geometry.collapsedFrame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        contentView = NSHostingView(
            rootView: IslandContent(
                layout: layout, model: model,
                toggle: { [weak self] in
                    guard let self else { return }
                    if self.expanded { self.closeAccounts() } else { self.showAccounts() }
                },
                close: { [weak self] in self?.closeAccounts() },
                hover: { [weak self] in self?.hover($0) },
                accountsChanged: { [weak self] in self?.render() }
            ))
        NotificationCenter.default.addObserver(
            self, selector: #selector(menuBegan(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(menuEnded(_:)), name: NSMenu.didEndTrackingNotification, object: nil)
        render()
    }

    func updateGeometry(_ geometry: NotchGeometry) {
        self.geometry = geometry
        render()
    }

    func showAccounts() {
        hoverTask?.cancel()
        layout.preview = false
        if !expanded { model.refreshWhenViewed() }
        expanded = true
        render()
        makeKeyAndOrderFront(nil)
    }

    func showAccount(_ id: AccountID?) {
        layout.navigation = AccountNavigationRequest(accountID: id)
        showAccounts()
    }

    private func closeAccounts() {
        hoverTask?.cancel()
        layout.preview = false
        expanded = false
        layout.navigation = AccountNavigationRequest()
        render()
    }

    private func hover(_ inside: Bool) {
        hoverTask?.cancel()
        guard trackingMenus.isEmpty else { return }
        if !inside {
            scheduleCollapse()
            return
        }
    }

    private func scheduleCollapse() {
        hoverTask?.cancel()
        guard trackingMenus.isEmpty else { return }
        hoverTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard let self, self.trackingMenus.isEmpty else { return }
            self.closeAccounts()
        }
    }

    @objc private func menuBegan(_ notification: Notification) {
        guard expanded, let menu = notification.object as? NSMenu else { return }
        trackingMenus.insert(ObjectIdentifier(menu))
        hoverTask?.cancel()
    }

    @objc private func menuEnded(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu,
            trackingMenus.remove(ObjectIdentifier(menu)) != nil,
            trackingMenus.isEmpty
        else { return }
        if !frame.contains(NSEvent.mouseLocation) { scheduleCollapse() }
    }

    private func render() {
        let frame =
            expanded
            ? geometry.expandedFrame(accountCount: model.snapshot.accounts.count)
            : layout.preview ? geometry.previewFrame : geometry.collapsedFrame
        setFrame(frame, display: true)
        layout.geometry = geometry
        layout.width = frame.width
        layout.height = frame.height
        layout.contentHeight = frame.height - geometry.collapsedFrame.height
    }

    #if WATERLINE_VERIFICATION
        func exportVerificationImage(to url: URL) async throws {
            if CommandLine.arguments.contains("--verification-route-account") {
                layout.navigation = AccountNavigationRequest(accountID: AccountID(rawValue: "verification-claude-code"))
            } else if CommandLine.arguments.contains("--verification-route-missing") {
                layout.navigation = AccountNavigationRequest(accountID: AccountID(rawValue: "verification-missing"))
            }
            layout.preview = CommandLine.arguments.contains("--verification-preview")
            expanded = !CommandLine.arguments.contains("--verification-collapsed") && !layout.preview
            render()
            try await Task.sleep(for: .milliseconds(100))
            guard let view = contentView else { throw VerificationRenderError.unavailable }
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor(calibratedWhite: 0.24, alpha: 1).cgColor
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw VerificationRenderError.unavailable
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw VerificationRenderError.unavailable
            }
            try data.write(to: url, options: .atomic)
        }

        private enum VerificationRenderError: Error { case unavailable }
    #endif
}
