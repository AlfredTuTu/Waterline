import SwiftUI
import WaterlineKit

struct CollapsedBar: View {
    let geometry: NotchGeometry
    let model: AppModel
    let displayWidth: CGFloat
    let showMetrics: Bool
    let toggle: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in bar }
    }

    private var bar: some View {
        let edgeInset: CGFloat = 18
        let wingWidth = (displayWidth - geometry.notchWidth) / 2
        let accounts = Dashboard.notchAccounts(model.snapshot)
        return HStack(spacing: 0) {
            ProviderLogo(provider: accounts.first?.account.provider)
                .frame(width: 18, height: 18)
                .frame(width: wingWidth - edgeInset, alignment: .leading)
                .padding(.leading, edgeInset)
            Color.clear.frame(width: geometry.notchWidth)
            Group {
                if let first = accounts.first {
                    metric(first)
                } else {
                    Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                }
            }
            .frame(width: wingWidth - edgeInset, alignment: .trailing)
            .padding(.trailing, edgeInset)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .frame(width: displayWidth, height: geometry.collapsedFrame.height)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            accounts.isEmpty ? AppText.text("Connect accounts") : accounts.map(description).joined(separator: ", ")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
        .help(accounts.isEmpty ? AppText.text("Connect accounts") : accounts.map(description).joined(separator: "\n"))
    }

    private func metric(_ entry: AccountEntry) -> some View {
        Text(compactValue(entry))
            .lineLimit(1)
            .monospacedDigit()
    }

    private func compactValue(_ entry: AccountEntry) -> String {
        let value = Dashboard.accountHeadline(entry, preferences: model.snapshot.preferences, now: Date())
        if case .quota(let used) = value {
            return "\(Int(((1 - min(1, max(0, used))) * 100).rounded()))%"
        }
        return model.headlineText(value)
    }

    private func description(_ entry: AccountEntry) -> String {
        let label = [entry.account.provider.displayName, entry.preferences.label].compactMap { $0 }.joined(
            separator: " · ")
        let value = model.headlineText(
            Dashboard.accountHeadline(entry, preferences: model.snapshot.preferences, now: Date()))
        if case .quota = Dashboard.accountHeadline(entry, preferences: model.snapshot.preferences, now: Date()) {
            return "\(label), \(AppText.format("%@ remaining", compactValue(entry)))"
        }
        return "\(label), \(value)"
    }
}
