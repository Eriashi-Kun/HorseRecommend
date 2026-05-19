import Foundation

struct PlayerStats {

    // MARK: - Constants

    static let xpPerPrediction = 10
    static let xpPerHit        = 30

    // 現レベルから次レベルに上がるのに必要なXP（ポケモン式）
    static func xpToNextLevel(from level: Int) -> Int {
        switch level {
        case 1...9:   return 25
        case 10...19: return 65
        case 20...29: return 210
        case 30...49: return 350
        case 50...59: return 500
        case 60...79: return 750
        case 80...99: return 1000
        default:      return 0  // Lv.100 が上限
        }
    }

    // totalXP からレベル・現レベル内XP・次レベルまでのXP を計算
    static func computeLevel(from totalXP: Int) -> (level: Int, xpInLevel: Int, xpToNext: Int) {
        var remaining = totalXP
        var lv = 1
        while lv < 100 {
            let needed = xpToNextLevel(from: lv)
            if remaining < needed {
                return (lv, remaining, needed)
            }
            remaining -= needed
            lv += 1
        }
        return (100, 0, 0)
    }

    // MARK: - Properties

    let totalXP: Int
    let level: Int
    let xpInLevel: Int
    let xpToNext: Int
    var xpProgress: Double { xpToNext > 0 ? Double(xpInLevel) / Double(xpToNext) : 1.0 }
    var title: String { Self.title(for: level) }

    let streak: Int
    let totalPredictions: Int   // 全予想数（結果未取得含む）
    let resolvedCount: Int      // 結果取得済み予想数
    let pendingCount: Int       // 結果待ち予想数
    let hitCount: Int           // 複勝数（結果取得済みのみ）
    var hitRate: Double { resolvedCount > 0 ? Double(hitCount) / Double(resolvedCount) : 0 }

    let typeStats: [String: TypeStat]

    struct TypeStat {
        let total: Int   // 結果取得済みのみ
        let hits: Int
        var rate: Double { total > 0 ? Double(hits) / Double(total) : 0 }
    }

    // MARK: - Init

    init(records: [PredictionRecord]) {
        var total = 0
        var resolved = 0
        var hits  = 0
        var typeMap: [String: (total: Int, hits: Int)] = [:]

        for record in records {
            let pos = record.picks.first?.finishPosition
            total += 1

            guard let pos else { continue }
            let isHit = pos >= 1 && pos <= 3
            resolved += 1
            if isHit { hits += 1 }

            let key = record.predictionType
            var s = typeMap[key] ?? (0, 0)
            s.total += 1
            if isHit { s.hits += 1 }
            typeMap[key] = s
        }

        totalPredictions = total
        resolvedCount = resolved
        pendingCount = total - resolved
        hitCount = hits
        typeStats = typeMap.mapValues { TypeStat(total: $0.total, hits: $0.hits) }

        let xp = total * Self.xpPerPrediction + hits * Self.xpPerHit
        totalXP = xp
        let (lv, inLv, toNext) = Self.computeLevel(from: xp)
        level     = lv
        xpInLevel = inLv
        xpToNext  = toNext

        // 結果取得済みレコードの直近連続複勝
        let resolvedRecords = records
            .filter { $0.picks.first?.finishPosition != nil }
            .sorted { $0.savedAt > $1.savedAt }
        var s = 0
        for record in resolvedRecords {
            let pos = record.picks.first?.finishPosition ?? 99
            if pos >= 1 && pos <= 3 { s += 1 } else { break }
        }
        streak = s
    }

    // MARK: - Title

    static func title(for level: Int) -> String {
        switch level {
        case 1...10:  return "見習い"
        case 11...20: return "予想師"
        case 21...30: return "中堅予想師"
        case 31...40: return "上級予想師"
        case 41...50: return "エキスパート"
        case 51...60: return "マスター"
        case 61...70: return "神予想師"
        case 71...80: return "伝説の予想師"
        case 81...90: return "競馬の覇者"
        default:      return "競馬神"
        }
    }
}
