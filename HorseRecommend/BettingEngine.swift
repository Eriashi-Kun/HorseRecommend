import Foundation

// MARK: - HorseScoringService

struct HorseScoringService {

    func score(_ horse: Horse, race: Race) -> Double {
        var s = placeRate(for: horse.odds) * 100

        let isDirt    = race.distance.hasPrefix("ダ")
        let distance  = Int(race.distance.filter { $0.isNumber }) ?? 2000
        let isWet     = race.condition == "重" || race.condition == "不良"
        let isSemiWet = race.condition == "稍重"

        if isDirt && distance <= 1400 {
            switch horse.runningStyle {
            case .front:   s += 18
            case .stalker: s += 10
            case .midpack: s -= 6
            case .closer:  s -= 14
            }
        } else if isDirt && distance <= 1800 {
            switch horse.runningStyle {
            case .front:   s += 8
            case .stalker: s += 4
            case .midpack: s -= 2
            case .closer:  s -= 6
            }
        }

        if isWet {
            switch horse.runningStyle {
            case .front:   s -= 10
            case .stalker: s -= 4
            case .midpack: s += 6
            case .closer:  s += 12
            }
        } else if isSemiWet {
            switch horse.runningStyle {
            case .front:   s -= 4
            case .stalker: s -= 1
            case .midpack: s += 2
            case .closer:  s += 5
            }
        }

        return max(1, min(100, s))
    }

    private func placeRate(for odds: Double) -> Double {
        switch odds {
        case ..<1.5:  return 0.79
        case ..<2.0:  return 0.72
        case ..<3.0:  return 0.60
        case ..<4.0:  return 0.49
        case ..<5.0:  return 0.41
        case ..<7.0:  return 0.33
        case ..<10.0: return 0.25
        case ..<15.0: return 0.19
        case ..<20.0: return 0.14
        case ..<30.0: return 0.11
        case ..<50.0: return 0.08
        default:      return 0.05
        }
    }
}

// MARK: - ModeStrategy

struct ModeStrategy {

    func sort(horses: [Horse], scoreFn: (Horse) -> Double, mode: RecommendMode) -> [Horse] {
        switch mode {
        case .safe:
            return horses.sorted { scoreFn($0) > scoreFn($1) }

        case .balanced:
            return horses.sorted { a, b in
                let aMid = a.odds >= 5 && a.odds <= 20
                let bMid = b.odds >= 5 && b.odds <= 20
                if aMid != bMid { return aMid }
                return scoreFn(a) > scoreFn(b)
            }

        case .romantic:
            let base = horses.sorted { scoreFn($0) > scoreFn($1) }
            guard base.count > 1 else { return base }
            let anchor = base[0]
            let rest = Array(base[1...]).sorted { a, b in
                if (a.odds >= 15) != (b.odds >= 15) { return a.odds >= 15 }
                return scoreFn(a) > scoreFn(b)
            }
            return [anchor] + rest
        }
    }
}

// MARK: - BetTypeSelector

struct BetTypeSelector {
    private let order = ["win", "place", "wide", "quinella", "exacta", "trio", "trifecta"]

    // 常にユーザーの手動選択を使用する
    func tickets(selectedTickets: Set<String>) -> [String] {
        order.filter { selectedTickets.contains($0) }
    }
}

// MARK: - BetGenerator

struct BetGenerator {

    func generate(ticket: String,
                  axis: Horse?,
                  sorted: [Horse],
                  mode: RecommendMode,
                  budgetShare: Int) -> [BettingInstruction] {
        guard !sorted.isEmpty else { return [] }
        let maxByBudget = max(1, budgetShare / 100)

        switch ticket {
        case "win":      return makeWinPlace(label: "単勝", axis: axis, sorted: sorted)
        case "place":    return makeWinPlace(label: "複勝", axis: axis, sorted: sorted)
        case "wide":     return makeWide(axis: axis, sorted: sorted, maxByBudget: maxByBudget)
        case "quinella": return makeQuinella(axis: axis, sorted: sorted, maxByBudget: maxByBudget)
        case "exacta":   return makeExacta(axis: axis, sorted: sorted, maxByBudget: maxByBudget)
        case "trio":     return makeTrio(axis: axis, sorted: sorted, maxByBudget: maxByBudget)
        case "trifecta": return makeTrifecta(axis: axis, sorted: sorted, budgetShare: budgetShare)
        default:         return []
        }
    }

    // MARK: 単勝・複勝（常に1通り）

    private func makeWinPlace(label: String, axis: Horse?, sorted: [Horse]) -> [BettingInstruction] {
        let h = axis ?? sorted[0]
        return [.init(ticketLabel: label, style: .single([h]), combinationCount: 1)]
    }

    // MARK: ワイド（流し: 最大5通り／ボックス: 4頭まで=最大6通り）

    private func makeWide(axis: Horse?, sorted: [Horse], maxByBudget: Int) -> [BettingInstruction] {
        if let ax = axis {
            let n = min(5, maxByBudget, sorted.count)
            guard n >= 1 else { return [] }
            let opps = Array(sorted.prefix(n)).sorted { $0.number < $1.number }
            return [.init(ticketLabel: "ワイド", style: .nagashi(axis: [ax], opponents: opps), combinationCount: opps.count)]
        } else {
            var n = 2
            while n < sorted.count && n + 1 <= 4 && comb(n + 1, 2) <= maxByBudget { n += 1 }
            let h = Array(sorted.prefix(n)).sorted { $0.number < $1.number }
            guard h.count >= 2 else { return [] }
            return [.init(ticketLabel: "ワイド", style: .box(horses: h), combinationCount: comb(h.count, 2))]
        }
    }

    // MARK: 馬連（流し: 最大6通り／ボックス: 5頭まで=最大10通り）

    private func makeQuinella(axis: Horse?, sorted: [Horse], maxByBudget: Int) -> [BettingInstruction] {
        if let ax = axis {
            let n = min(6, maxByBudget, sorted.count)
            guard n >= 1 else { return [] }
            let opps = Array(sorted.prefix(n)).sorted { $0.number < $1.number }
            return [.init(ticketLabel: "馬連", style: .nagashi(axis: [ax], opponents: opps), combinationCount: opps.count)]
        } else {
            var n = 2
            while n < sorted.count && n + 1 <= 5 && comb(n + 1, 2) <= maxByBudget { n += 1 }
            let h = Array(sorted.prefix(n)).sorted { $0.number < $1.number }
            guard h.count >= 2 else { return [] }
            return [.init(ticketLabel: "馬連", style: .box(horses: h), combinationCount: comb(h.count, 2))]
        }
    }

    // MARK: 馬単（マルチ: 6頭×両方向=最大12通り）

    private func makeExacta(axis: Horse?, sorted: [Horse], maxByBudget: Int) -> [BettingInstruction] {
        let ax = axis ?? sorted[0]
        let pool: [Horse] = axis != nil ? sorted : (sorted.count > 1 ? Array(sorted.dropFirst()) : [])
        guard !pool.isEmpty else { return [] }
        // マルチは1相手あたり2通りなので maxByBudget/2 が上限
        let n = min(6, maxByBudget / 2, pool.count)
        guard n >= 1 else { return [] }
        let opps = Array(pool.prefix(n)).sorted { $0.number < $1.number }
        return [.init(ticketLabel: "馬単", style: .nagashi(axis: [ax], opponents: opps), combinationCount: opps.count * 2)]
    }

    // MARK: 三連複（1頭軸流し: 6頭まで=最大15通り）

    private func makeTrio(axis: Horse?, sorted: [Horse], maxByBudget: Int) -> [BettingInstruction] {
        let ax = axis ?? sorted[0]
        let pool: [Horse] = axis != nil ? sorted : (sorted.count > 1 ? Array(sorted.dropFirst()) : [])
        guard pool.count >= 2 else { return [] }
        var n = 2
        while n < pool.count && n + 1 <= 6 && comb(n + 1, 2) <= maxByBudget { n += 1 }
        let opps = Array(pool.prefix(n)).sorted { $0.number < $1.number }
        let count = comb(opps.count, 2)
        guard count > 0 else { return [] }
        return [.init(ticketLabel: "三連複", style: .nagashi(axis: [ax], opponents: opps), combinationCount: count)]
    }

    // MARK: 三連単（1着軸流し: 最大60通り、余り予算は抑えフォーメーションとして追加）

    private func makeTrifecta(axis: Horse?, sorted: [Horse], budgetShare: Int) -> [BettingInstruction] {
        guard let ax = axis ?? sorted.first else { return [] }
        let pool: [Horse] = axis != nil ? sorted : (sorted.count > 1 ? Array(sorted.dropFirst()) : [])
        guard pool.count >= 2 else { return [] }

        let totalCombos = budgetShare / 100
        guard totalCombos >= 2 else { return [] }

        // Primary: N×(N-1) ≤ min(60, totalCombos)
        let primaryMax = min(60, totalCombos)
        var n = pool.count
        while n >= 2 && n * (n - 1) > primaryMax { n -= 1 }
        guard n >= 2 else { return [] }
        let primaryCombos = n * (n - 1)
        let primaryOpps = Array(pool.prefix(n)).sorted { $0.number < $1.number }
        let primary = BettingInstruction(
            ticketLabel: "三連単",
            style: .formation(first: [ax], second: primaryOpps, third: primaryOpps),
            combinationCount: primaryCombos
        )

        let remainingCombos = totalCombos - primaryCombos
        guard remainingCombos >= 1 else { return [primary] }

        // Secondary: 抑えフォーメーション（より広い馬を使用）
        let secOpps = Array(pool.prefix(min(pool.count, n + 3))).sorted { $0.number < $1.number }
        let secondary = BettingInstruction(
            ticketLabel: "三連単",
            style: .formation(first: [ax], second: secOpps, third: secOpps),
            combinationCount: remainingCombos
        )
        return [primary, secondary]
    }

    // MARK: Helpers

    private func comb(_ n: Int, _ k: Int) -> Int {
        guard n >= k, k > 0 else { return 0 }
        if k == 2 { return n * (n - 1) / 2 }
        if k == 3 { return n * (n - 1) * (n - 2) / 6 }
        return 1
    }
}

// MARK: - BudgetAllocator

struct BudgetAllocator {

    // 券種ごとの予算配分ウェイト（重みに比例して按分）
    private let weightByLabel: [String: Double] = [
        "単勝": 1.5, "複勝": 1.5,
        "ワイド": 1.2, "馬連": 1.0, "馬単": 0.8,
        "三連複": 0.7, "三連単": 0.5,
    ]

    // 三連単のみ100円固定。他券種は上限なし（予算を使い切るため）
    private let fixedPerCombo: [String: Int] = [
        "三連単": 100,
    ]

    func allocate(budget: Int, items: inout [BettingInstruction]) {
        guard !items.isEmpty else { return }

        // ウェイトを正規化しbudgetShare計算
        let totalWeight = items.reduce(0.0) { $0 + (weightByLabel[$1.ticketLabel] ?? 1.0) }
        let shares: [Int] = items.map { item in
            Int(Double(budget) * (weightByLabel[item.ticketLabel] ?? 1.0) / totalWeight)
        }

        // Step1: 初期金額（三連単は100円固定、他は按分額を100円単位に切り捨て）
        for i in items.indices {
            let pts = items[i].combinationCount
            if let fixed = fixedPerCombo[items[i].ticketLabel] {
                items[i].amountPerCombination = fixed
            } else {
                let raw = shares[i] / pts / 100 * 100
                items[i].amountPerCombination = max(100, raw)
            }
        }

        // Step2: Greedy（三連単以外を対象に、点数の少ない順で100円ずつ追加）
        var remaining = budget - items.reduce(0) { $0 + $1.totalAmount }
        var changed = true
        while changed && remaining > 0 {
            changed = false
            for idx in items.indices.sorted(by: { items[$0].combinationCount < items[$1].combinationCount }) {
                guard fixedPerCombo[items[idx].ticketLabel] == nil else { continue }
                let step = 100 * items[idx].combinationCount
                if remaining >= step {
                    items[idx].amountPerCombination += 100
                    remaining -= step
                    changed = true
                    break
                }
            }
        }

        // Step3: Pair swap（+100/-100 の差額で残りを吸収）
        if remaining > 0 {
            outer: for ri in items.indices {
                guard fixedPerCombo[items[ri].ticketLabel] == nil else { continue }
                let rs = 100 * items[ri].combinationCount
                for li in items.indices where li != ri {
                    guard fixedPerCombo[items[li].ticketLabel] == nil else { continue }
                    let ls = 100 * items[li].combinationCount
                    if rs - ls == remaining && items[li].amountPerCombination > 100 {
                        items[ri].amountPerCombination += 100
                        items[li].amountPerCombination -= 100
                        remaining = 0
                        break outer
                    }
                }
            }
        }

        // Step4: 余りを追加買い目として生成（三連単はBetGeneratorで対応済みなので対象外）
        if remaining >= 100 {
            let absorbOrder = ["三連複", "馬単", "馬連", "ワイド", "単勝", "複勝"]
            for label in absorbOrder {
                guard remaining >= 100 else { break }
                if let primary = items.first(where: { $0.ticketLabel == label }) {
                    let subCombos = remaining / 100
                    let sub = makeSubInstruction(from: primary, subCombos: subCombos)
                    items.append(sub)
                    remaining = 0
                }
            }
        }
    }

    private func makeSubInstruction(from primary: BettingInstruction, subCombos: Int) -> BettingInstruction {
        let subStyle: BuyingStyle
        switch primary.style {
        case .single(let horses):
            subStyle = .single(horses)
        case .nagashi(let axis, let opponents):
            let n = min(subCombos, opponents.count)
            subStyle = .nagashi(axis: axis, opponents: Array(opponents.prefix(n)))
        case .box(let horses):
            var n = 2
            while n < horses.count && n + 1 <= horses.count && comb(n + 1, 2) <= subCombos { n += 1 }
            subStyle = .box(horses: Array(horses.prefix(max(2, n))))
        case .formation(let first, let second, let third):
            subStyle = .formation(first: first, second: second, third: third)
        }
        return BettingInstruction(ticketLabel: primary.ticketLabel, style: subStyle, combinationCount: subCombos)
    }

    private func comb(_ n: Int, _ k: Int) -> Int {
        guard n >= k, k > 0 else { return 0 }
        if k == 2 { return n * (n - 1) / 2 }
        return 1
    }
}

// MARK: - ResultCommentGenerator

struct ResultCommentGenerator {

    func generate(mode: RecommendMode, axis: Horse?, ticketIds: [String]) -> String {
        let axisText = axis.map { "\($0.name)（\($0.number)番）を軸に、" } ?? ""
        switch mode {
        case .safe:
            return "\(axisText)安定重視で人気上位を中心に構成しました"
        case .balanced:
            return "\(axisText)妙味のある中穴馬を組み合わせたバランス構成です"
        case .romantic:
            return ticketIds.contains("trifecta")
                ? "\(axisText)高配当狙いでフォーメーションを広げています"
                : "\(axisText)ロマン重視で穴馬を多めに組み込みました"
        }
    }
}

// MARK: - PredictionEngine

struct PredictionEngine {

    private let scorer    = HorseScoringService()
    private let strategy  = ModeStrategy()
    private let selector  = BetTypeSelector()
    private let generator = BetGenerator()
    private let allocator = BudgetAllocator()
    private let commenter = ResultCommentGenerator()

    private let weightByTicket: [String: Double] = [
        "win": 1.5, "place": 1.5,
        "wide": 1.2, "quinella": 1.0, "exacta": 0.8,
        "trio": 0.7, "trifecta": 0.5,
    ]

    func predict(
        race: Race,
        mode: RecommendMode,
        budget: Int,
        selectedTickets: Set<String>,
        pivotHorse: Horse?
    ) -> (items: [BettingInstruction], comment: String) {
        guard race.horses.count >= 3 else { return ([], "") }

        // 1. スコアリング & モード別ソート
        let scoreFn: (Horse) -> Double = { self.scorer.score($0, race: race) }
        let sorted = strategy.sort(horses: race.horses, scoreFn: scoreFn, mode: mode)

        // 2. 軸馬を除いた候補リスト
        let others = sorted.filter { $0.id != (pivotHorse?.id ?? UUID()) }

        // 3. 券種リスト（常にユーザー手動選択を使用）
        let ticketIds = selector.tickets(selectedTickets: selectedTickets)
        guard !ticketIds.isEmpty else { return ([], "") }

        // 4. ウェイト正規化 → 券種ごとのbudgetShare（点数上限の判定に使用）
        let totalWeight = ticketIds.reduce(0.0) { $0 + (weightByTicket[$1] ?? 1.0) }

        // 5. ベット生成
        var items: [BettingInstruction] = ticketIds.flatMap { tid in
            let share = Int(Double(budget) * (weightByTicket[tid] ?? 1.0) / totalWeight)
            return generator.generate(ticket: tid, axis: pivotHorse, sorted: others, mode: mode, budgetShare: share)
        }
        guard !items.isEmpty else { return ([], "") }

        // 6. 予算配分
        allocator.allocate(budget: budget, items: &items)

        // 7. コメント
        let comment = commenter.generate(mode: mode, axis: pivotHorse, ticketIds: ticketIds)

        return (items, comment)
    }
}
