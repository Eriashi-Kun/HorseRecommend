//
//  HorseRecommendApp.swift
//  HorseRecommend
//
//  Created by Shutaro Makino on 2026/04/26.
//

import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct HorseRecommendApp: App {
    @State private var adManager = RewardedAdManager()
    @State private var weights = UserWeightsManager()

    init() {
        MobileAds.shared.start()
        NotificationManager.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            PredictionTypeSelectView()
                .environment(adManager)
                .environment(weights)
        }
        .modelContainer(for: [PredictionRecord.self, TicketRecord.self])
    }
}
