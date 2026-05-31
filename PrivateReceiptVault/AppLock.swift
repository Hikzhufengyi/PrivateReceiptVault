import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AppLock: ObservableObject {
    @AppStorage("app_lock_enabled") var isEnabled = false
    @Published var isUnlocked = true
    @Published var isShieldVisible = false
    @Published var errorMessage: String?
    private var isAuthenticating = false

    var lockName: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            default: return "device authentication"
            }
        }
        return "device authentication"
    }

    func lockIfNeeded() {
        guard !isAuthenticating else { return }
        guard isEnabled else {
            isUnlocked = true
            isShieldVisible = false
            return
        }
        isUnlocked = false
        isShieldVisible = true
    }

    func showPrivacyShieldIfNeeded() {
        guard !isAuthenticating else { return }
        guard isEnabled else { return }
        isShieldVisible = true
    }

    func prepareForForeground() {
        guard !isAuthenticating else { return }
        guard !isUnlocked else {
            isShieldVisible = false
            return
        }
        guard isEnabled else {
            isUnlocked = true
            isShieldVisible = false
            return
        }
        isUnlocked = false
        isShieldVisible = true
    }

    func authenticate() {
        guard !isAuthenticating else { return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        isAuthenticating = true

        Task {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Unlock your private receipt vault."
                )
                await MainActor.run {
                    isAuthenticating = false
                    isUnlocked = success
                    isShieldVisible = !success
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    errorMessage = error.localizedDescription
                    isUnlocked = false
                    isShieldVisible = true
                }
            }
        }
    }
}
