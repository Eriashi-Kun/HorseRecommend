import SwiftUI

// MARK: - RunningStyle

enum RunningStyle: String {
    case front   = "逃"
    case stalker = "先"
    case midpack = "差"
    case closer  = "追"

    var color: Color {
        switch self {
        case .front:   return Color(red: 1.00, green: 0.02, blue: 0.65)  // magenta
        case .stalker: return Color(red: 0.00, green: 0.95, blue: 1.00)  // cyan
        case .midpack: return Color(red: 1.00, green: 0.88, blue: 0.00)  // yellow
        case .closer:  return Color(red: 0.72, green: 0.00, blue: 1.00)  // purple
        }
    }
}

// MARK: - Horse

struct Horse: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let odds: Double
    let runningStyle: RunningStyle
}

// MARK: - Race

enum RaceGrade: String {
    case g1 = "G1"
    case g2 = "G2"
    case g3 = "G3"
    case listed = "L"
    case open = "OP"
    case special = ""

    var displayText: String { rawValue.isEmpty ? "OP" : rawValue }

    var color: Color {
        switch self {
        case .g1:             return Color(red: 1.00, green: 0.02, blue: 0.65)  // magenta
        case .g2:             return Color(red: 0.72, green: 0.00, blue: 1.00)  // purple
        case .g3:             return Color(red: 0.00, green: 0.95, blue: 1.00)  // cyan
        case .listed:         return Color(red: 1.00, green: 0.88, blue: 0.00)  // yellow
        case .open, .special: return Color(red: 0.45, green: 0.43, blue: 0.58)
        }
    }
}

struct Race: Identifiable {
    let id = UUID()
    let day: String   // "YYYYMMDD" date string from backend
    let venue: String
    let raceNumber: String
    let name: String
    let grade: RaceGrade
    let distance: String
    let condition: String
    let time: String
    let horses: [Horse]

    var isPast: Bool {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyyMMdd"
        let today = dateFmt.string(from: Date())
        if day < today { return true }
        if day > today { return false }
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        return time < timeFmt.string(from: Date())
    }

    // OP badge only for named OP races — not for class-based races
    var showsGradeBadge: Bool {
        switch grade {
        case .g1, .g2, .g3, .listed: return true
        case .open, .special:
            return !name.contains("未勝利")
                && !name.contains("勝クラス")
                && !name.contains("新馬")
        }
    }
}

// MARK: - PredictionType

enum PredictionType: String, CaseIterable, Identifiable {
    case safe     = "固め"
    case midRange = "中穴"
    case longShot = "爆穴"

    var id: String { rawValue }

    var apiKey: String {
        switch self {
        case .safe:     return "safe"
        case .midRange: return "midRange"
        case .longShot: return "longShot"
        }
    }

    var subtitle: String {
        switch self {
        case .safe:     return "人気馬を堅実に狙う"
        case .midRange: return "期待値の高い中穴馬"
        case .longShot: return "一発逆転の大穴狙い"
        }
    }

    var emoji: String {
        switch self {
        case .safe:     return "🎯"
        case .midRange: return "⚡"
        case .longShot: return "🔥"
        }
    }

    var color: Color {
        switch self {
        case .safe:     return Color(red: 0.00, green: 0.95, blue: 1.00)  // cyan
        case .midRange: return Color(red: 1.00, green: 0.88, blue: 0.00)  // yellow
        case .longShot: return Color(red: 0.72, green: 0.00, blue: 1.00)  // purple
        }
    }
}

// MARK: - Recommendation

struct Recommendation {
    let horse: Horse
    let race: Race
    let type: PredictionType
    let reason: String
    let score: Double
    let popularityRank: Int
}
