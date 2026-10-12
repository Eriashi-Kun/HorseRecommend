import Foundation

enum Config {
    static let backendURL = "https://pakapick-api.fly.dev"

    #if DEBUG
    static let bannerAdUnitID    = "ca-app-pub-3940256099942544/2934735716"
    static let rewardedAdUnitID  = "ca-app-pub-3940256099942544/1712485313"
    #else
    static let bannerAdUnitID    = "ca-app-pub-8763709237464698/6270808180"
    static let rewardedAdUnitID  = "ca-app-pub-8763709237464698/5424630370"
    #endif
}
