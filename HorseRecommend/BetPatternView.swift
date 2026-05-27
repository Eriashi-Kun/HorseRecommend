import SwiftUI

// 券種パターンに応じた買い目表示コンポーネント
struct BetPatternView: View {
    let betPattern: String
    let betType: String
    let isMulti: Bool
    let bets: [NetworkRaceRepository.ParsedBet]
    let perAmount: Int

    private var effectiveIsMulti: Bool { isMulti && multiCapableBetTypes.contains(betType) }

    var body: some View {
        switch betPattern {
        case "ながし":
            nagashiView
        case "ボックス":
            boxView
        default:
            defaultView
        }
    }

    // MARK: - ながし表示（軸 → 相手）

    private func nagashiPivotAndPartners() -> (pivot: Int?, partners: [Int]) {
        let allSets = bets.map { Set($0.horses) }
        let common = allSets.dropFirst().reduce(allSets.first ?? []) { $0.intersection($1) }
        let pivot = common.first ?? bets.first?.horses.first
        var partners: [Int] = []
        var seen = Set<Int>()
        for bet in bets {
            for h in bet.horses where h != pivot {
                if seen.insert(h).inserted { partners.append(h) }
            }
        }
        return (pivot, partners)
    }

    private var nagashiView: some View {
        let (pivot, partners) = nagashiPivotAndPartners()
        return VStack(alignment: .leading, spacing: 8) {
            if let pivot {
                HStack(spacing: 6) {
                    horseNumBadge(pivot, color: SplatTheme.yellow)
                    Image(systemName: effectiveIsMulti ? "arrow.left.arrow.right" : "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                    HStack(spacing: 4) {
                        ForEach(partners, id: \.self) { num in
                            horseNumBadge(num, color: SplatTheme.cyan)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text("\(bets.count)点")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("各\(perAmount)円")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - ボックス表示

    private var boxView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let allHorses = Array(Set(bets.flatMap { $0.horses })).sorted()
            HStack(spacing: 4) {
                ForEach(allHorses, id: \.self) { num in
                    horseNumBadge(num, color: SplatTheme.cyan)
                }
            }
            HStack(spacing: 8) {
                Text("\(bets.count)点")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                Text("各\(perAmount)円")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - 通常/フォーメーション（1点ずつ列挙）

    private var defaultView: some View {
        VStack(spacing: 6) {
            ForEach(bets.indices, id: \.self) { i in
                let bet = bets[i]
                HStack {
                    Text(bet.horses.map(String.init).joined(separator: " - "))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("¥\(bet.amount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SplatTheme.cyan)
                }
            }
        }
    }

    // MARK: - Helper

    private func horseNumBadge(_ num: Int, color: Color) -> some View {
        Text("\(num)")
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .frame(width: 30, height: 30)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 1))
    }
}

// TicketRecord版（保存済みデータ用）
struct TicketBetPatternView: View {
    let ticket: TicketRecord

    private var asParsedBets: [NetworkRaceRepository.ParsedBet] {
        ticket.bets.map { NetworkRaceRepository.ParsedBet(horses: $0.horses, amount: $0.amount) }
    }

    var body: some View {
        BetPatternView(
            betPattern: ticket.betPattern,
            betType: ticket.betType,
            isMulti: ticket.isMulti,
            bets: asParsedBets,
            perAmount: ticket.bets.first?.amount ?? 0
        )
    }
}
