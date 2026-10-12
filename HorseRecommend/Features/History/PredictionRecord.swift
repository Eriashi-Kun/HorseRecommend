import SwiftData
import Foundation

@Model
class PredictionRecord {
    var id: UUID = UUID()
    var savedAt: Date = Date()
    var raceId: String = ""
    var raceName: String = ""
    var venue: String = ""
    var raceNumber: String = ""
    var day: String = ""
    var predictionType: String = ""
    var weightsKey: String = ""
    var picksData: Data = Data()

    init(raceId: String, raceName: String, venue: String, raceNumber: String,
         day: String, predictionType: String, weightsKey: String, picks: [PickData]) {
        self.id = UUID()
        self.savedAt = Date()
        self.raceId = raceId
        self.raceName = raceName
        self.venue = venue
        self.raceNumber = raceNumber
        self.day = day
        self.predictionType = predictionType
        self.weightsKey = weightsKey
        self.picksData = (try? JSONEncoder().encode(picks)) ?? Data()
    }

    var picks: [PickData] {
        get { (try? JSONDecoder().decode([PickData].self, from: picksData)) ?? [] }
        set { picksData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var predictionTypeEnum: PredictionType? {
        PredictionType.allCases.first { $0.rawValue == predictionType }
    }
}

struct PickData: Codable {
    let horseNumber: Int
    let horseName: String
    let odds: Double
    var finishPosition: Int?
}
