import SwiftUI

struct OnboardingViewController: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Private Receipt Vault",
            subtitle: "Keep receipts, bills, and reimbursement records organized without an account.",
            systemImage: "lock.shield.fill",
            accent: .blue
        ),
        OnboardingPage(
            title: "Offline by Design",
            subtitle: "OCR runs on device. Receipts stay in local app storage unless you export or back them up.",
            systemImage: "wifi.slash",
            accent: .green
        ),
        OnboardingPage(
            title: "Scan, Extract, Review",
            subtitle: "Capture receipts, adjust the scan, and review structured fields like tax, tip, card last 4, and line items.",
            systemImage: "doc.text.viewfinder",
            accent: .indigo
        ),
        OnboardingPage(
            title: "Export and Backup",
            subtitle: "Create professional reports, ZIP packages, and optional password-protected .receiptvaultbackup files.",
            systemImage: "externaldrive.badge.checkmark",
            accent: .teal
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                Button {
                    if page == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(.snappy) {
                            page += 1
                        }
                    }
                } label: {
                    Text(page == pages.count - 1 ? "Get Started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onFinish()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.background)
        }
    }
}

private struct OnboardingPage {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let accent: Color
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 40)

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(page.accent.opacity(0.14))
                    .frame(width: 132, height: 132)
                Image(systemName: page.systemImage)
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(page.accent)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            HStack(spacing: 10) {
                TrustBadge(icon: "lock", text: "No account")
                TrustBadge(icon: "iphone.gen3", text: "On-device OCR")
            }

            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct TrustBadge: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.background, in: Capsule())
            .overlay {
                Capsule().stroke(.secondary.opacity(0.18), lineWidth: 1)
            }
    }
}
