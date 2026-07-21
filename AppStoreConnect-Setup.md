# App Store Connect Setup

## Auto-Renewable Subscriptions

Create one subscription group named `Receipt Vault Pro` with two products:

- Monthly: `receiptvault.pro.monthly`, one month, US price `$2.99`.
- Yearly: `receiptvault.pro.yearly`, one year, US price `$19.99`.
- Both products use the same service level and unlock the same Pro features.
- Do not configure a free trial or introductory offer.
- Use localized display names and descriptions for every supported App Store locale.

The app uses StoreKit 2 in `StoreKitService.swift`.

## Legacy Lifetime Purchase

Keep `receiptvault.pro.lifetime` available for entitlement restoration but do not promote it to new users. Existing lifetime purchasers must retain permanent Pro access. Do not reuse or change the type of this product ID.

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
- Increment `MARKETING_VERSION` by `0.1` for each upload, using one decimal place. For example: `1.9 -> 2.0`, `2.0 -> 2.1`.
- Set `CURRENT_PROJECT_VERSION` to the upload date in `yyyyMMdd` format. For example: `20260710`.
- Create the subscription group and both subscription product IDs above in App Store Connect.
- Set the US prices to `$2.99/month` and `$19.99/year`, then review Apple's equivalent prices for other storefronts.
- Confirm the legacy lifetime product remains available for restoration.
- Test monthly purchase, yearly purchase, renewal, cancellation/expiration, upgrade/downgrade, lifetime restore, and subscription restore in Sandbox and TestFlight.
- Keep the local "Unlock Pro for testing" button only in debug/TestFlight builds before public release.

## Export Compliance

The app uses standard Apple platform encryption APIs for local password-protected backup files and device authentication. The generated Info.plist includes:

- `ITSAppUsesNonExemptEncryption = NO`

In App Store Connect, answer the export compliance questions consistently with the app behavior: encryption is used only to protect user data, the app is not a VPN, secure messaging, encrypted calling, anonymization, or general-purpose cryptography product.
