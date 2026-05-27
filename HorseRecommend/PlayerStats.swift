import Foundation

struct PlayerStats {

    // MARK: - Constants

    static let xpPerPrediction = 10
    static let xpPerHit        = 30

    static func xpForTicketHit(betType: String) -> Int {
        switch betType {
        case "三連単": return 80
        case "三連複": return 50
        case "馬単":   return 40
        case "馬連":   return 30
        case "ワイド": return 25
        default:      return 20  // 単勝・複勝
        }
    }

    static func xpToNextLevel(from level: Int) -> Int {
        switch level {
        case 1...10:  return 25
        case 11...20: return 65
        case 21...30: return 150
        case 31...40: return 280
        case 41...50: return 420
        case 51...60: return 600
        case 61...70: return 800
        case 71...80: return 1000
        case 81...90: return 1200
        case 91...99: return 1500
        default:      return 0
        }
    }

    static func computeLevel(from totalXP: Int) -> (level: Int, xpInLevel: Int, xpToNext: Int) {
        var remaining = totalXP
        var lv = 1
        while lv < 100 {
            let needed = xpToNextLevel(from: lv)
            if remaining < needed { return (lv, remaining, needed) }
            remaining -= needed
            lv += 1
        }
        return (100, 0, 0)
    }

    // MARK: - AI Prediction Properties

    let totalXP: Int
    let level: Int
    let xpInLevel: Int
    let xpToNext: Int
    var xpProgress: Double { xpToNext > 0 ? Double(xpInLevel) / Double(xpToNext) : 1.0 }
    var title: String { Self.title(for: level) }

    let streak: Int
    let totalPredictions: Int
    let resolvedCount: Int
    let pendingCount: Int
    let hitCount: Int
    var hitRate: Double { resolvedCount > 0 ? Double(hitCount) / Double(resolvedCount) : 0 }
    let typeStats: [String: TypeStat]

    struct TypeStat {
        let total: Int
        let hits: Int
        var rate: Double { total > 0 ? Double(hits) / Double(total) : 0 }
    }

    // MARK: - Ticket Properties

    let ticketResolvedCount: Int
    let ticketHitCount: Int
    var ticketHitRate: Double { ticketResolvedCount > 0 ? Double(ticketHitCount) / Double(ticketResolvedCount) : 0 }
    let ticketBetStats: [String: TicketBetStat]

    struct TicketBetStat {
        let total: Int
        let hits: Int
        let invested: Int
        let returned: Int
        var hitRate: Double { total > 0 ? Double(hits) / Double(total) : 0 }
        var returnRate: Double { invested > 0 ? Double(returned) / Double(invested) : 0 }
    }

    // MARK: - Init

    init(records: [PredictionRecord], tickets: [TicketRecord] = []) {
        // AI prediction stats
        var total = 0
        var resolved = 0
        var hits = 0
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

        // Ticket stats
        var tMap: [String: (total: Int, hits: Int, invested: Int, returned: Int)] = [:]
        for ticket in tickets {
            var s = tMap[ticket.betType] ?? (0, 0, 0, 0)
            s.total += 1
            if ticket.isHit { s.hits += 1 }
            s.invested += ticket.totalAmount
            s.returned += ticket.payout
            tMap[ticket.betType] = s
        }
        let resolvedTickets = tickets.filter { $0.isResolved }
        ticketResolvedCount = resolvedTickets.count
        ticketHitCount = resolvedTickets.filter { $0.isHit }.count
        ticketBetStats = tMap.mapValues {
            TicketBetStat(total: $0.total, hits: $0.hits, invested: $0.invested, returned: $0.returned)
        }

        // Combined XP: AI predictions + ticket hits
        let predXP = total * Self.xpPerPrediction + hits * Self.xpPerHit
        let ticketXP = tickets.filter { $0.isHit }.reduce(0) { $0 + Self.xpForTicketHit(betType: $1.betType) }
        totalXP = predXP + ticketXP

        let (lv, inLv, toNext) = Self.computeLevel(from: totalXP)
        level     = lv
        xpInLevel = inLv
        xpToNext  = toNext

        // Streak from resolved AI prediction records
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
