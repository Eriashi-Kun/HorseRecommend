import Foundation

final class NetworkRaceRepository {
    private let baseURL: String
    private var cache: [Race]?

    init(baseURL: String = Config.backendURL) {
        self.baseURL = baseURL
    }

    func fetchRaces() async throws -> [Race] {
        if let cache { return cache }

        guard let url = URL(string: "\(baseURL)/races") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let dtos = try JSONDecoder().decode([RaceDTO].self, from: data)
        let races = dtos.map { $0.toRace() }
        cache = races
        return races
    }

    func currentRace(from races: [Race]) -> Race {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let targetDay: RaceDay = weekday == 1 ? .sunday : .saturday

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let currentTime = formatter.string(from: now)

        let dayRaces = races
            .filter { $0.day == targetDay }
            .sorted { $0.time < $1.time }

        return dayRaces.first(where: { $0.time >= currentTime })
            ?? dayRaces.last
            ?? races.first
            ?? sampleRaces[0]
    }
}
