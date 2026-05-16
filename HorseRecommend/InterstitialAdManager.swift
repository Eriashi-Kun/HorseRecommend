import GoogleMobileAds
import UIKit
import Observation

@MainActor
@Observable
class InterstitialAdManager {
    private var interstitial: InterstitialAd?

    private let adUnitID = "ca-app-pub-8763709237464698/8850630257"
    private let freeLimit = 3
    private let countKey = "adPredictionsToday"
    private let dateKey  = "adLastDate"

    init() {
        Task { await load() }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var predictionsToday: Int {
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

    func load() async {
        do {
            interstitial = try await InterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
        } catch {
            print("Interstitial ad failed to load: \(error)")
        }
    }

    func showIfNeeded() {
        predictionsToday += 1

        guard predictionsToday > freeLimit else { return }
        guard let ad = interstitial,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else { return }
        ad.present(from: root)
        interstitial = nil
        Task { await load() }
    }
}
