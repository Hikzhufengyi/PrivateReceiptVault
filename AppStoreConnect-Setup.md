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
- Expense reports and insights
- Backup and restore
- Duplicate receipt detection
- Face ID privacy lock

## Before Release

- Replace bundle identifier `com.example.PrivateReceiptVault` with the final App Store bundle ID.
- Create the product ID above in App Store Connect.
- Add pricing and availability for the non-consumable purchase.
- Test purchase and restore in Sandbox and TestFlight.
- Keep the local "Unlock Pro for testing" button only in debug/TestFlight builds before public release.
