import Foundation

// MARK: - RaceRepository
// データソースを差し替えるときはこのプロトコルに準拠した実装を作るだけでよい

protocol RaceRepository {
    func fetchRaces() -> [Race]
    func fetchCurrentRace() -> Race
}
