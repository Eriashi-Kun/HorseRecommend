import SwiftUI
import Combine

final class RecommendationViewModel: ObservableObject {
    @Published var recommendations: [Recommendation] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading = false
    @Published var usedAI = false

    var current: Recommendation? { recommendations[safe: currentIndex] }
    var hasNext: Bool { currentIndex + 1 < recommendations.count }

    private let engine = RecommendationEngine()
    private let repository: RaceRepository

    init(repository: RaceRepository = MockRaceRepository()) {
        self.repository = repository
    }

    @MainActor
    func load(type: PredictionType, race: Race? = nil, weights: UserWeightsManager? = nil) async {
        let target = race ?? repository.fetchCurrentRace()
        isLoading = true
        defer { isLoading = false }

        do {
            let picks = try await fetchFromNetwork(race: target, type: type)
            recommendations = picks
            usedAI = true
        } catch {
            print("AI recommendation failed, falling back to local engine: \(error)")
            recommendations = engine.recommendations(race: target, type: type, weights: weights)
            usedAI = false
        }
        currentIndex = 0
    }

    @MainActor
    func showNext() {
        guard hasNext else { return }
        currentIndex += 1
    }

    // MARK: - Network

    private func fetchFromNetwork(race: Race, type: PredictionType) async throws -> [Recommendation] {
        guard let url = URL(string: "\(Config.backendURL)/recommend") else {
            throw URLError(.badURL)
        }

        let body = RecommendRequest(race: .init(from: race), type: type.apiKey)
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let result = try JSONDecoder().decode(RecommendResponse.self, from: data)
        let horseMap = Dictionary(uniqueKeysWithValues: race.horses.map { ($0.number, $0) })
        let sorted = race.horses.sorted { $0.odds < $1.odds }

        return result.picks.compactMap { pick in
            guard let horse = horseMap[pick.number] else { return nil }
            let rank = (sorted.firstIndex(where: { $0.id == horse.id }) ?? 0) + 1
            return Recommendation(
                horse: horse,
                race: race,
                type: type,
                reason: pick.reason,
                score: pick.score,
                popularityRank: rank
            )
        }
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
