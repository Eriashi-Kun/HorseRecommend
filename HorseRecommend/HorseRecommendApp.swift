//
//  HorseRecommendApp.swift
//  HorseRecommend
//
//  Created by Shutaro Makino on 2026/04/26.
//

import SwiftUI
import GoogleMobileAds

@main
struct HorseRecommendApp: App {
    @State private var adManager = InterstitialAdManager()
    @State private var weights = UserWeightsManager()

    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            PredictionTypeSelectView()
                .environment(adManager)
                .environment(weights)
        }
    }
}
