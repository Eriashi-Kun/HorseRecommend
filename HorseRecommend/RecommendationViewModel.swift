import SwiftUI
import Combine

@MainActor
final class RecommendationViewModel: ObservableObject {
    @Published var recommendations: [Recommendation] = []
    @Published var currentIndex: Int = 0

    var current: Recommendation? { recommendations[safe: currentIndex] }
    var hasNext: Bool { currentIndex + 1 < recommendations.count }

    private let engine = RecommendationEngine()
    private let repository: RaceRepository

    init(repository: RaceRepository = MockRaceRepository()) {
        self.repository = repository
    }

    func load(type: PredictionType, race: Race? = nil) {
        let target = race ?? repository.fetchCurrentRace()
        recommendations = engine.recommendations(race: target, type: type)
        currentIndex = 0
    }

    func showNext() {
        guard hasNext else { return }
        currentIndex += 1
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
