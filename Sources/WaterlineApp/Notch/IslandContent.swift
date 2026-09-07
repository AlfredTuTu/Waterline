import Observation
import SwiftUI
import WaterlineKit

@Observable
final class IslandLayout {
    var geometry: NotchGeometry
    var expanded = false
    var preview = false
    var keyboardActive = false
    var navigation = AccountNavigationRequest()
    var width: CGFloat
    var height: CGFloat
    var contentHeight: CGFloat = 0

    init(geometry: NotchGeometry) {
        self.geometry = geometry
        width = geometry.collapsedFrame.width
        height = geometry.collapsedFrame.height
    }
}

struct IslandContent: View {
    let layout: IslandLayout
    let model: AppModel
    let toggle: () -> Void
    let close: () -> Void
    let hover: (Bool) -> Void
    let accountsChanged: () -> Void

    var body: some View {
        let silhouette = IslandSilhouette(
            expanded: layout.expanded, attachedToTop: layout.geometry.style == .notch)
        VStack(spacing: 0) {
            CollapsedBar(
                geometry: layout.geometry, model: model, displayWidth: layout.width,
                showMetrics: layout.preview || layout.expanded, toggle: toggle)
            if layout.expanded {
                AccountsView(
                    model: model, width: layout.width, keyboardActive: layout.keyboardActive,
                    navigation: layout.navigation, close: close
                )
                .frame(height: layout.contentHeight)
            }
        }
        .frame(width: layout.width, height: layout.height)
        .background(.black, in: silhouette)
        .clipShape(silhouette)
        .contentShape(silhouette)
        .onHover(perform: hover)
        .onChange(of: model.snapshot.accounts.count) { _, _ in accountsChanged() }
        .environment(\.locale, AppLocalization.shared.locale)
    }
}
