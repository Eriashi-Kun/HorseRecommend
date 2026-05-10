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
        var request = URLRequest(url: url, timeoutInterval: 180)
        request.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: request)
        let dtos = try JSONDecoder().decode([RaceDTO].self, from: data)
        let races = dtos.map { $0.toRace() }
        cache = races
        return races
    }

    func currentRace(from races: [Race]) -> Race {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyyMMdd"
        let today = dateFmt.string(from: Date())

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let currentTime = timeFmt.string(from: Date())

        let todayRaces = races.filter { $0.day == today }.sorted { $0.time < $1.time }
        if let next = todayRaces.first(where: { $0.time >= currentTime }) { return next }
        if let last = todayRaces.last { return last }

        let upcoming = races.sorted { $0.day < $1.day || ($0.day == $1.day && $0.time < $1.time) }
        return upcoming.first ?? sampleRaces[0]
    }
}
