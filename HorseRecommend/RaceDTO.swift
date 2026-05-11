import Foundation

// MARK: - DTOs (API JSON → Swift Models)

struct RaceDTO: Codable {
    let day: String
    let venue: String
    let raceNumber: String
    let name: String
    let grade: String
    let distance: String
    let condition: String
    let time: String
    let horses: [HorseDTO]

    enum CodingKeys: String, CodingKey {
        case day, venue, name, grade, distance, condition, time, horses
        case raceNumber = "race_number"
    }

    func toRace() -> Race {
        Race(
            day: day,
            venue: venue,
            raceNumber: raceNumber,
            name: name,
            grade: parsedGrade,
            distance: distance,
            condition: condition,
            time: time,
            horses: horses.map { $0.toHorse() }
        )
    }

    private var parsedGrade: RaceGrade {
        switch grade.lowercased() {
        case "g1":              return .g1
        case "g2":              return .g2
        case "g3":              return .g3
        case "listed", "l":     return .listed
        default:                return .open
        }
    }
}

// MARK: - Recommendation DTOs

struct RecommendRequest: Encodable {
    let race: RaceInput
    let type: String

    struct RaceInput: Encodable {
        let name: String
        let venue: String
        let day: String
        let time: String
        let distance: String
        let condition: String
        let horses: [HorseInput]
        let race_number: String

        init(from race: Race) {
            name = race.name
            venue = race.venue
            day = race.day
            time = race.time
            distance = race.distance
            condition = race.condition
            race_number = race.raceNumber
            horses = race.horses.map {
                HorseInput(number: $0.number, name: $0.name, odds: $0.odds,
                           gate: $0.gate, sex: $0.sex, age: $0.age,
                           jockey: $0.jockey, weight: $0.weight, horse_id: $0.horseId)
            }
        }
    }

    struct HorseInput: Encodable {
        let number: Int
        let name: String
        let odds: Double
        let gate: Int
        let sex: String
        let age: Int
        let jockey: String
        let weight: Double
        let horse_id: String
    }
}

struct RecommendResponse: Decodable {
    let picks: [Pick]

    struct Pick: Decodable {
        let number: Int
        let name: String
        let odds: Double
        let score: Double
        let reason: String
    }
}

// MARK: - Horse DTO

struct HorseDTO: Codable {
    let number: Int
    let name: String
    let odds: Double
    let runningStyle: String?
    let gate: Int?
    let sex: String?
    let age: Int?
    let jockey: String?
    let weight: Double?
    let horseId: String?

    enum CodingKeys: String, CodingKey {
        case number, name, odds, gate, sex, age, jockey, weight
        case runningStyle = "running_style"
        case horseId = "horse_id"
    }

    func toHorse() -> Horse {
        let style: RunningStyle
        switch runningStyle {
        case "front":   style = .front
        case "stalker": style = .stalker
        case "closer":  style = .closer
        default:        style = .midpack
        }
        return Horse(
            number: number, name: name, odds: odds, runningStyle: style,
            gate: gate ?? 0, sex: sex ?? "", age: age ?? 0,
            jockey: jockey ?? "", weight: weight ?? 0,
            horseId: horseId ?? ""
        )
    }
}
