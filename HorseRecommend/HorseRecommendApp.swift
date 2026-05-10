//
//  HorseRecommendApp.swift
//  HorseRecommend
//
//  Created by Shutaro Makino on 2026/04/26.
//

import SwiftUI

@main
struct HorseRecommendApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                RecommendInputView(race: Self.nearestRace())
            }
        }
    }

    private static func nearestRace() -> Race {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let targetDay: RaceDay = weekday == 1 ? .sunday : .saturday

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let currentTime = formatter.string(from: now)

        let dayRaces = sampleRaces
            .filter { $0.day == targetDay }
            .sorted { $0.time < $1.time }

        return dayRaces.first(where: { $0.time >= currentTime })
            ?? dayRaces.last
            ?? sampleRaces[0]
    }
}
