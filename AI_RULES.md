# AI Rules

These rules apply to all future iOS code changes in this repository.

## No Hardcoded UI Values

- Do not hardcode colors directly in views.
- All colors must come from the app Theme layer.
- If a required semantic color does not exist, add it to Theme first, then use the Theme token.
- Avoid direct usage such as `Color(red:green:blue:)`, hex colors, scattered `.green`, `.orange`, `.blue`, `.secondary.opacity(...)`, or UIKit colors in feature views unless the Theme explicitly exposes them.
- Use semantic names, for example `Theme.Colors.primaryAction`, `Theme.Colors.warning`, `Theme.Colors.cardBackground`, `Theme.Colors.success`.

## All User-Facing Strings Must Be Localized

- Do not hardcode user-facing strings in SwiftUI views, alerts, buttons, labels, empty states, errors, onboarding, paywalls, export UI, or settings.
- Every user-facing string must be defined in `Localizable.strings`.
- Swift code should reference localized values with `String(localized:)`, `LocalizedStringKey`, or an existing localization helper.
- When adding a new string, add at least the English and Simplified Chinese entries. Keep other locale files in sync when practical.
- Developer-only logs, internal identifiers, enum raw values used for persistence, and non-user-visible test fixtures may remain unlocalized.

## Before Finishing A Change

- Search changed files for direct color literals and replace them with Theme tokens.
- Search changed files for visible string literals and move them to `Localizable.strings`.
- Do not introduce new UI copy or color values without updating localization and Theme.
