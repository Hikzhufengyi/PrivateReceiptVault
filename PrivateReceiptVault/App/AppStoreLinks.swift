import Foundation

enum AppStoreLinks {
    static let appID = "6775111870"
    static let appURL = URL(string: "https://apps.apple.com/app/id\(appID)")!
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")!
    static let privacyPolicyURL = URL(string: "https://getreceiptvault.com/privacy")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
