import GoogleMobileAds
import UIKit
import Observation

@MainActor
@Observable
class InterstitialAdManager {
    private var interstitial: InterstitialAd?

    private let adUnitID = "ca-app-pub-8763709237464698/8850630257"
    private let freeLimit = 2
    private let racesKey = "adRacesUsedToday"
    private let dateKey  = "adLastDate"

    init() {
        Task { await load() }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var racesUsedToday: Set<String> {
        get {
            let saved = UserDefaults.standard.string(forKey: dateKey) ?? ""
            if saved != todayString {
                UserDefaults.standard.set(todayString, forKey: dateKey)
                UserDefaults.standard.set([String](), forKey: racesKey)
                return []
            }
            let arr = UserDefaults.standard.stringArray(forKey: racesKey) ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(todayString, forKey: dateKey)
            UserDefaults.standard.set(Array(newValue), forKey: racesKey)
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

    func showIfNeeded(raceID: String) {
        var races = racesUsedToday
        races.insert(raceID)
        racesUsedToday = races

        guard races.count > freeLimit else { return }
        guard let ad = interstitial,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else { return }
        ad.present(from: root)
        interstitial = nil
        Task { await load() }
    }
}
