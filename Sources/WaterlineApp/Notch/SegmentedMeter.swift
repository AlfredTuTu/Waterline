import SwiftUI

struct SegmentedMeter: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let count = max(1, min(120, Int(geometry.size.width / 7)))
            segments(Color.white.opacity(0.12), count: count)
                .overlay {
                    segments(color, count: count)
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: geometry.size.width * min(1, max(0, fraction)))
                        }
                }
        }
        .frame(height: 17)
        .accessibilityHidden(true)
    }

    private func segments(_ color: Color, count: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5).fill(color)
            }
        }
    }
}
