import SwiftUI

struct TrustBadgesView: View {
    var compact = false
    @State private var selectedBadgeTitle: String?

    private let badges: [TrustBadgeItem] = [
        TrustBadgeItem(title: "私密", detail: "数据不上传云端", icon: "🔒"),
        TrustBadgeItem(title: "AI识别", detail: "自动识别金额和商户", icon: "⚡"),
        TrustBadgeItem(title: "加密备份", detail: "换手机也能恢复", icon: "☁"),
        TrustBadgeItem(title: "本地离线", detail: "数据不上云", icon: "📴")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: compact ? 6 : 8) {
                ForEach(badges) { badge in
                    TrustBadgeButton(
                        badge: badge,
                        compact: compact,
                        isSelected: selectedBadgeTitle == badge.title
                    ) {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedBadgeTitle = selectedBadgeTitle == badge.title ? nil : badge.title
                        }
                    }
                }
            }

            if let selectedBadge {
                Text(selectedBadge.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel(selectedBadge.detail)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var selectedBadge: TrustBadgeItem? {
        badges.first { $0.title == selectedBadgeTitle }
    }
}

private struct TrustBadgeItem: Identifiable {
    let title: String
    let detail: String
    let icon: String

    var id: String { title }
}

private struct TrustBadgeButton: View {
    let badge: TrustBadgeItem
    let compact: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(badge.icon)
                    .font(.caption)
                Text(String(localized: String.LocalizationValue(badge.title)))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 6 : 8)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.accentColor.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(badge.title)，点击展开详情")
    }
}
