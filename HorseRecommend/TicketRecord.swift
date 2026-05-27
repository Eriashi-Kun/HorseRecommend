import SwiftData
import Foundation

@Model
class TicketRecord {
    var id: UUID = UUID()
    var savedAt: Date = Date()
    var raceDate: String = ""       // "20260523"
    var venue: String = ""          // "東京"
    var raceNumber: String = ""     // "9R"
    var raceName: String = ""       // "カーネーションカップ"（任意）
    var raceId: String = ""         // "202606060901" レース結果取得用
    var betType: String = ""        // "複勝" "ワイド" "馬単" "三連複" etc.
    var betPattern: String = ""     // "通常" "ながし" "フォーメーション" "ボックス"
    var isMulti: Bool = false       // マルチ（WHEEL）フラグ
    var betsData: Data = Data()     // [BetEntry] をJSONエンコード
    var totalAmount: Int = 0        // 合計購入金額（円）
    var payout: Int = 0             // 払戻金額（0=ハズレまたは未確定）
    var isResolved: Bool = false    // 結果取得済みか

    init(raceDate: String, venue: String, raceNumber: String, raceName: String,
         betType: String, betPattern: String, isMulti: Bool = false,
         bets: [BetEntry], totalAmount: Int) {
        self.raceDate = raceDate
        self.venue = venue
        self.raceNumber = raceNumber
        self.raceName = raceName
        self.betType = betType
        self.betPattern = betPattern
        self.isMulti = isMulti
        self.betsData = (try? JSONEncoder().encode(bets)) ?? Data()
        self.totalAmount = totalAmount
    }

    var bets: [BetEntry] {
        get { (try? JSONDecoder().decode([BetEntry].self, from: betsData)) ?? [] }
        set { betsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var netAmount: Int { payout - totalAmount }
    var isHit: Bool { isResolved && payout > 0 }

    // 払戻テーブルを照合してP&Lを確定する
    // payoutsMap: 券種 → [{horses, amount}] (amountは100円あたり払戻)
    func resolvePayout(payoutsMap: [String: [NetworkRaceRepository.PayoutEntry]]) {
        let typePayouts = payoutsMap[betType] ?? []
        var updatedBets = bets
        var total = 0

        let orderedTypes: Set<String> = ["馬単", "三連単"]

        for i in updatedBets.indices {
            let entry = updatedBets[i]
            for p in typePayouts {
                let matched = orderedTypes.contains(betType)
                    ? entry.horses == p.horses
                    : Set(entry.horses) == Set(p.horses)
                if matched {
                    updatedBets[i].unitPayout = p.amount
                    total += entry.amount * p.amount / 100
                    break
                }
            }
        }
        bets = updatedBets
        payout = total
        isResolved = true
    }
}

// マルチが存在する券種（連単系のみ）
let multiCapableBetTypes: Set<String> = ["馬単", "三連単"]

// 1つの買い目（例：ワイド 1-11 @ 1,000円）
struct BetEntry: Codable {
    var horses: [Int]       // 関係する馬番（順序あり：三連単等）
    var amount: Int         // この組み合わせの購入金額
    var unitPayout: Int     // 100円あたり払戻（取得後に設定）

    init(horses: [Int], amount: Int, unitPayout: Int = 0) {
        self.horses = horses
        self.amount = amount
        self.unitPayout = unitPayout
    }

    var payout: Int {
        guard unitPayout > 0 else { return 0 }
        return amount * unitPayout / 100
    }
}
