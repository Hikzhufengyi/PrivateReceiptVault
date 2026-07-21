import SwiftUI

enum Theme {
    static let titleLevel1 = Color(uiColor: .label)
    static let titleLevel2 = Color(uiColor: .secondaryLabel)
    static let titleLevel3 = Color(uiColor: .tertiaryLabel)

    static let appGreen = Color(red: 0.08, green: 0.55, blue: 0.31)
    static let appRed = Color(red: 0.78, green: 0.13, blue: 0.16)
    static let tint = Color.accentColor

    static let searchBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let subscriptionSelectionBackground = Color.accentColor.opacity(0.10)
    static let subscriptionBadgeBackground = Color.accentColor.opacity(0.14)
    static let secondarySurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
}
