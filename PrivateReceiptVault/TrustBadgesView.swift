import SwiftUI

struct TrustBadgesView: View {
    var compact = false

    private let badges: [(String, String)] = [
        ("Offline", "wifi.slash"),
        ("On-device OCR", "iphone.gen3"),
        ("No account", "person.crop.circle.badge.xmark"),
        ("Encrypted backup", "externaldrive.badge.checkmark")
    ]

    var body: some View {
        FlowLayout(spacing: compact ? 6 : 8) {
            ForEach(badges, id: \.0) { badge in
                Label(badge.0, systemImage: badge.1)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 8 : 10)
                    .padding(.vertical, compact ? 6 : 7)
                    .background(.tint.opacity(0.10), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.tint.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline, on-device OCR, no account, encrypted backup")
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                width = max(width, rowWidth)
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? spacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        width = max(width, rowWidth)
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
