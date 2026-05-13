import Foundation

// MARK: - RecommendationEngine
// PredictionTypeに応じて候補馬をスコアリングし、おすすめ順に返す

struct RecommendationEngine {

    // おすすめ馬リストを返す（「別の馬を見る」はこのリストをインデックスで辿る）
    func recommendations(race: Race, type: PredictionType, weights: UserWeightsManager? = nil) -> [Recommendation] {
        let candidates = selectCandidates(horses: race.horses, type: type)
        return candidates.map { horse in
            let rank = popularityRank(of: horse, in: race.horses)
            return Recommendation(
                horse: horse,
                race: race,
                type: type,
                reason: makeReason(horse: horse, race: race, type: type, rank: rank),
                score: calculateScore(horse: horse, race: race, type: type, weights: weights),
                popularityRank: rank
            )
        }
    }

    // MARK: - 候補馬選定

    private func selectCandidates(horses: [Horse], type: PredictionType) -> [Horse] {
        let sorted = horses.sorted { $0.odds < $1.odds }
        switch type {
        case .safe:
            // オッズ低め（人気上位）から最大3頭
            return Array(sorted.prefix(3))

        case .midRange:
            // 5〜20倍の中穴ゾーン。いなければ人気3〜5番手
            let mid = sorted.filter { $0.odds >= 5 && $0.odds <= 20 }
            if mid.isEmpty {
                let fallback = sorted.dropFirst(2).prefix(3)
                return Array(fallback)
            }
            return Array(mid.prefix(3))

        case .longShot:
            // 15倍以上の穴馬。展開・馬場が向く脚質を優先
            let pool = sorted.filter { $0.odds >= 15 }
            let favored = favoredStyle(for: horses.first.map { _ in horses[0] }, race: nil)
            let styled = pool.filter { $0.runningStyle == favored }
            if styled.isEmpty && pool.isEmpty {
                return Array(sorted.suffix(3).reversed())
            }
            let result = styled.isEmpty ? pool : styled
            return Array(result.prefix(3))
        }
    }

    // MARK: - スコア計算（1〜99）

    func calculateScore(horse: Horse, race: Race, type: PredictionType, weights: UserWeightsManager? = nil) -> Double {
        let popularityFactor = weights.map { $0.popularity / 50.0 } ?? 1.0
        var score = placeRate(odds: horse.odds) * 100 * popularityFactor

        let isDirt = race.distance.hasPrefix("ダ")
        let isWet  = race.condition == "重" || race.condition == "不良"

        // 脚質 × 馬場補正
        switch horse.runningStyle {
        case .front:
            score += isDirt ? 12 : (isWet ? -8 : 2)
        case .stalker:
            score += isDirt ? 5 : 3
        case .midpack:
            score += isWet ? 5 : 0
        case .closer:
            score += isWet ? 10 : (isDirt ? -5 : 0)
        }

        // タイプ別のスコア意味づけ
        switch type {
        case .safe:
            break
        case .midRange:
            if horse.odds >= 5 && horse.odds <= 20 { score += 10 }
        case .longShot:
            score = (1.0 / horse.odds) * 300 + Double(horse.runningStyle == favoredStyle(for: nil, race: race) ? 20 : 0)
        }

        if let w = weights {
            // 騎手重視度: 0=オフ, 100=max +15
            let jockeyStrength = stableHash(horse.jockey)
            score += w.jockey / 100.0 * 15.0 * jockeyStrength

            // 過去成績重視度: 0=オフ, 100=max +12
            let formStrength = stableHash(horse.name + "_form")
            score += w.history / 100.0 * 12.0 * formStrength

            // 可愛さ: 0=オフ, 100=max +20
            let cutenessScore = stableHash(horse.name + "_cute")
            score += w.cuteness / 100.0 * 20.0 * cutenessScore

            // 直感: 0=オフ, 100=max +15
            let intuitionScore = stableHash(horse.name + race.day + "_luck")
            score += w.intuition / 100.0 * 15.0 * intuitionScore
        }

        return max(1, min(99, score.rounded()))
    }

    // FNV-1a hash → stable 0.0-1.0 value for a string
    private func stableHash(_ s: String) -> Double {
        var h: UInt64 = 14695981039346656037
        for byte in s.utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        return Double(h % 1000) / 999.0
    }

    // MARK: - 推奨理由生成

    private func makeReason(horse: Horse, race: Race, type: PredictionType, rank: Int) -> String {
        let styleLabel = horse.runningStyle.rawValue + "脚質"
        let conditionNote = conditionComment(horse: horse, race: race)

        switch type {
        case .safe:
            return "\(rank)番人気（オッズ\(horse.odds)倍）。安定した\(styleLabel)で崩れにくく、本命候補筆頭です。\(conditionNote)"
        case .midRange:
            return "\(rank)番人気（オッズ\(horse.odds)倍）。配当妙味がある中穴ゾーン。\(styleLabel)が今の展開にマッチします。\(conditionNote)"
        case .longShot:
            return "\(rank)番人気（オッズ\(horse.odds)倍）の大穴馬。\(styleLabel)が今の馬場でハマれば大波乱も。\(conditionNote)"
        }
    }

    private func conditionComment(horse: Horse, race: Race) -> String {
        let isWet  = race.condition == "重" || race.condition == "不良"
        let isDirt = race.distance.hasPrefix("ダ")
        if isWet && horse.runningStyle == .closer {
            return "道悪は差し馬に有利な傾向。"
        }
        if isDirt && horse.runningStyle == .front {
            return "ダートは逃げ・先行馬が有利。"
        }
        return ""
    }

    // MARK: - Helpers

    private func favoredStyle(for horse: Horse?, race: Race?) -> RunningStyle {
        let isDirt = race?.distance.hasPrefix("ダ") ?? false
        let isWet  = race?.condition == "重" || race?.condition == "不良"
        if isWet   { return .closer }
        if isDirt  { return .front }
        return .midpack
    }

    private func popularityRank(of horse: Horse, in horses: [Horse]) -> Int {
        let sorted = horses.sorted { $0.odds < $1.odds }
        return (sorted.firstIndex(where: { $0.id == horse.id }) ?? 0) + 1
    }

    private func placeRate(odds: Double) -> Double {
        switch odds {
        case ..<2.0:  return 0.75
        case ..<3.0:  return 0.62
        case ..<5.0:  return 0.48
        case ..<8.0:  return 0.34
        case ..<15.0: return 0.22
        case ..<30.0: return 0.13
        default:      return 0.07
        }
    }
}
