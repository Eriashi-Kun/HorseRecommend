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
            day: RaceDay(rawValue: day) ?? .saturday,
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

struct HorseDTO: Codable {
    let number: Int
    let name: String
    let odds: Double
    let runningStyle: String?

    enum CodingKeys: String, CodingKey {
        case number, name, odds
        case runningStyle = "running_style"
    }

    func toHorse() -> Horse {
        let style: RunningStyle
        switch runningStyle {
        case "front":   style = .front
        case "stalker": style = .stalker
        case "closer":  style = .closer
        default:        style = .midpack
        }
        return Horse(number: number, name: name, odds: odds, runningStyle: style)
    }
}
