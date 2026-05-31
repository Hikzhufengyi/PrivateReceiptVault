import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var proAccess: ProAccess
    @EnvironmentObject private var store: ReceiptStore
    @EnvironmentObject private var appLock: AppLock
    @State private var showingPaywall = false
    @State private var backupURL: URL?
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false
    @State private var backupMessage: String?
    @State private var backupPassword = ""
    @State private var restorePassword = ""
    @State private var showingClearConfirmation = false

    var body: some View {
        List {
            Section("Plan") {
                HStack {
                    Label(proAccess.isPro ? "Pro unlocked" : "Free plan", systemImage: proAccess.isPro ? "checkmark.seal.fill" : "seal")
                    Spacer()
                    Text(proAccess.isPro ? "Unlimited" : "\(ProAccess.freeReceiptLimit) receipts")
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                if proAccess.isPro {
                    Button("Reset Pro test unlock", role: .destructive) {
                        proAccess.resetForTesting()
                    }
                }
                #endif

                if !proAccess.isPro {
                    Button {
                        showingPaywall = true
                    } label: {
                        Label("Upgrade to Pro", systemImage: "lock.open")
                    }
                }
            }

            Section {
                Toggle("Require \(appLock.lockName)", isOn: $appLock.isEnabled)
                if appLock.isEnabled {
                    Button {
                        appLock.lockIfNeeded()
                    } label: {
                        Label("Lock now", systemImage: "lock")
                    }
                }
            } header: {
                Text("Security")
            } footer: {
                Text("When enabled, private receipts are hidden when the app leaves the foreground, including the app switcher preview, and require device authentication to unlock.")
            }

            Section {
                Label("No account required", systemImage: "person.crop.circle.badge.xmark")
                Label("No bank connection", systemImage: "creditcard.trianglebadge.exclamationmark")
                Label("OCR runs on device", systemImage: "iphone.gen3")
                Label("Receipts stay in local app storage", systemImage: "externaldrive.badge.shield.checkmark")
                LocalDataFlowView()
            } header: {
                Text("Privacy")
            } footer: {
                Text("Receipt Vault does not include a server, analytics SDK, or account system. Exports are created locally and shared only when you choose to share them.")
            }

            Section("Positioning") {
                Text("Private Receipt Vault is designed for freelancers, contractors, travelers, and small business owners who want an offline receipt organizer for reimbursement and tax-season records.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                SecureField("Backup password optional", text: $backupPassword)
                    .textContentType(.newPassword)

                Button {
                    createBackup()
                } label: {
                    Label("Export .receiptvaultbackup", systemImage: "externaldrive.badge.checkmark")
                }

                SecureField("Restore password if encrypted", text: $restorePassword)
                    .textContentType(.password)

                Button {
                    showingBackupImporter = true
                } label: {
                    Label("Restore from Files / iCloud Drive", systemImage: "icloud.and.arrow.down")
                }

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear all local data", systemImage: "trash")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Export backups to Files or iCloud Drive. After exporting outside the app, you can delete and reinstall Receipt Vault and restore from the backup file. Keep your backup password safe; it cannot be recovered.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingBackupExporter) {
            if let backupURL {
                DocumentExporter(url: backupURL)
            }
        }
        .sheet(isPresented: $showingBackupImporter) {
            DocumentImporter { url in
                restoreBackup(from: url)
            }
        }
        .alert("Backup", isPresented: Binding(
            get: { backupMessage != nil },
            set: { if !$0 { backupMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupMessage ?? "")
        }
        .confirmationDialog("Clear all local data?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear all local data", role: .destructive) {
                store.clearAllData()
                backupMessage = "All local receipts, reports, images, and exports were cleared."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes receipts, reports, receipt images, and generated exports from this device.")
        }
        .toolbar {
            Button("Done") {
                dismiss()
            }
        }
    }

    private func createBackup() {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptVault-\(Date().formatted(.iso8601.year().month().day())).receiptvaultbackup")
            try store.exportBackup(to: url, password: backupPassword)
            backupURL = url
            showingBackupExporter = true
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func restoreBackup(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            try store.importBackup(from: url, password: restorePassword)
            backupMessage = "Backup restored."
        } catch {
            backupMessage = "Restore failed. Check the backup file and password. \(error.localizedDescription)"
        }
    }
}

private struct LocalDataFlowView: View {
    private let steps: [(LocalizedStringKey, String)] = [
        ("Scan", "doc.viewfinder"),
        ("On-device OCR", "iphone.gen3"),
        ("Local vault", "lock.rectangle.stack"),
        ("Export by choice", "square.and.arrow.up")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Private data flow")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 5) {
                        Image(systemName: step.1)
                            .foregroundStyle(.tint)
                            .frame(width: 30, height: 30)
                            .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                        Text(step.0)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity)

                    if index < steps.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
