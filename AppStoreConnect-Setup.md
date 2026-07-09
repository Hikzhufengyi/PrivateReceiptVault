# App Store Connect Setup

## In-App Purchase

Create a non-consumable product:

- Product ID: `receiptvault.pro.lifetime`
- Reference name: `Receipt Vault Pro Lifetime`
- Type: Non-Consumable
- Suggested display name: `Receipt Vault Pro`
- Suggested description: `Unlimited private receipt storage, professional exports, expense reports, insights, backup and restore.`

The app uses StoreKit 2 in `StoreKitService.swift`.

## Free Plan

The free plan currently allows:

- 30 saved receipts
- CSV export
- Local OCR and privacy lock

Pro unlocks:

- Unlimited receipts
- PDF reports
- ZIP export with CSV and images
- Professional export packets

## Before Release

- Bundle identifier is set to `com.hikzhufengyi.receiptvault`.
- Create the product ID above in App Store Connect.
- Add pricing and availability for the non-consumable purchase.
- Test purchase and restore in Sandbox and TestFlight.
- Keep the local "Unlock Pro for testing" button only in debug/TestFlight builds before public release.

## Export Compliance

The app uses standard Apple platform encryption APIs for local password-protected backup files and device authentication. The generated Info.plist includes:

- `ITSAppUsesNonExemptEncryption = NO`

In App Store Connect, answer the export compliance questions consistently with the app behavior: encryption is used only to protect user data, the app is not a VPN, secure messaging, encrypted calling, anonymization, or general-purpose cryptography product.
