import Foundation
import UIKit

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

    struct PayoutEntry: Decodable { let horses: [Int]; let amount: Int }
    struct RaceResultFull: Decodable {
        struct HorseResult: Decodable { let number: Int; let finish: Int }
        let results: [HorseResult]
        let payouts: [String: [PayoutEntry]]
    }

    func fetchRaceResult(raceId: String) async -> [Int: Int] {
        guard let full = await fetchRaceResultFull(raceId: raceId) else { return [:] }
        return Dictionary(uniqueKeysWithValues: full.results.map { ($0.number, $0.finish) })
    }

    func fetchRaceResultFull(raceId: String) async -> RaceResultFull? {
        guard !raceId.isEmpty else { return nil }
        // デバイスから直接取得してバックエンドでパース（Fly.ioのIPがnetkeibaにブロックされるため）
        if let result = await _fetchResultViaDevice(raceId: raceId) { return result }
        // フォールバック：バックエンド直接
        guard let url = URL(string: "\(baseURL)/race/\(raceId)/result") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(RaceResultFull.self, from: data)
    }

    private func _fetchResultViaDevice(raceId: String) async -> RaceResultFull? {
        guard let netkeibaURL = URL(string: "https://race.netkeiba.com/race/result.html?race_id=\(raceId)") else { return nil }
        guard let (htmlData, _) = try? await URLSession.shared.data(from: netkeibaURL),
              !htmlData.isEmpty else { return nil }
        let base64 = htmlData.base64EncodedString()
        guard let parseURL = URL(string: "\(baseURL)/parse_result_html") else { return nil }
        var req = URLRequest(url: parseURL, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONEncoder().encode(["html_base64": base64]) else { return nil }
        req.httpBody = body
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return try? JSONDecoder().decode(RaceResultFull.self, from: data)
    }

    func findRaceId(date: String, venue: String, raceNumber: String) async -> String? {
        var comps = URLComponents(string: "\(baseURL)/find_race")
        comps?.queryItems = [
            .init(name: "date", value: date),
            .init(name: "venue", value: venue),
            .init(name: "race_number", value: raceNumber),
        ]
        guard let url = comps?.url else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct Resp: Decodable { let race_id: String }
        return (try? JSONDecoder().decode(Resp.self, from: data))?.race_id
    }

    struct ParsedBet: Decodable { let horses: [Int]; let amount: Int }
    struct TicketParseResult: Decodable {
        let raceDate: String
        let venue: String
        let raceNumber: String
        let raceName: String
        let betType: String
        let betPattern: String
        let isMulti: Bool?
        let bets: [ParsedBet]
        let totalAmount: Int
        let raceId: String?  // バックエンドで構築済みrace_id
    }

    func parseTicketVision(imageData: Data) async throws -> TicketParseResult {
        guard let url = URL(string: "\(baseURL)/parse_ticket_vision") else { throw URLError(.badURL) }
        // 長辺1600px以内・高品質JPEGで小文字も正確に読めるようにする
        let compressed = Self.compressImage(imageData, maxDimension: 1600, quality: 0.92)
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "image_base64": compressed.base64EncodedString(),
            "media_type": "image/jpeg",
        ]
        req.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(TicketParseResult.self, from: data)
    }

    private static func compressImage(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        if scale < 1.0 {
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
            return resized.jpegData(compressionQuality: quality) ?? data
        }
        return image.jpegData(compressionQuality: quality) ?? data
    }

    func parseTicket(ocrText: String) async throws -> TicketParseResult {
        guard let url = URL(string: "\(baseURL)/parse_ticket") else { throw URLError(.badURL) }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["ocr_text": ocrText])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(TicketParseResult.self, from: data)
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
