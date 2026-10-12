import GoogleMobileAds
import UIKit
import Observation

@MainActor
@Observable
class RewardedAdManager {
    private var rewardedAd: RewardedAd?
    private let adUnitID = Config.rewardedAdUnitID
    private let freeLimit = 5
    private let countKey = "rewardedPredictionsToday"
    private let dateKey  = "rewardedLastDate"

    init() {
        Task { await load() }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var predictionsToday: Int {
        get {
            let saved = UserDefaults.standard.string(forKey: dateKey) ?? ""
            if saved != todayString {
                UserDefaults.standard.set(todayString, forKey: dateKey)
                UserDefaults.standard.set(0, forKey: countKey)
                return 0
            }
            return UserDefaults.standard.integer(forKey: countKey)
        }
        set {
            UserDefaults.standard.set(todayString, forKey: dateKey)
            UserDefaults.standard.set(newValue, forKey: countKey)
        }
    }

    var needsAd: Bool { predictionsToday >= freeLimit }

    func load() async {
        do {
            rewardedAd = try await RewardedAd.load(
                with: adUnitID,
                request: Request()
            )
        } catch {
            print("Rewarded ad failed to load: \(error)")
        }
    }

    func incrementCount() {
        predictionsToday += 1
    }

    func showAd(onRewarded: @escaping () -> Void, onFailed: @escaping () -> Void) {
        guard let ad = rewardedAd,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            onFailed()
            return
        }
        ad.present(from: root, userDidEarnRewardHandler: {
            onRewarded()
        })
        rewardedAd = nil
        Task { await load() }
    }
}
