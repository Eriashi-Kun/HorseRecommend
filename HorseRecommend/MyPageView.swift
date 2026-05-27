import SwiftUI
import SwiftData

struct MyPageView: View {
    @Query(sort: \PredictionRecord.savedAt, order: .reverse) private var records: [PredictionRecord]
    @Query(sort: \TicketRecord.savedAt, order: .reverse) private var tickets: [TicketRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var showTickets = false

    private var stats: PlayerStats { PlayerStats(records: records, tickets: tickets) }
    private var ticketSpent: Int  { tickets.reduce(0) { $0 + $1.totalAmount } }
    private var ticketReturn: Int { tickets.reduce(0) { $0 + $1.payout } }
    private var ticketNet: Int    { ticketReturn - ticketSpent }

    var body: some View {
        NavigationStack {
            ZStack {
                SplatTheme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    titleBar
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            levelCard
                            ticketCard
                            ticketBetBreakdownCard
                            summaryRow
                            typeBreakdownCard
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
            #if !SCREENSHOTS
            .safeAreaInset(edge: .bottom) {
                LabeledBannerAdView(adUnitID: Config.bannerAdUnitID)
            }
            #endif
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showTickets) { TicketListView() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        ZStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(SplatTheme.card)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Text("マイページ")
                .font(.system(size: 17, weight: .black))
                .foregroundColor(.white)
        }
        .frame(height: 56)
        .background(SplatTheme.bg)
    }

    // MARK: - Level Card

    private var levelCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.title)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white.opacity(0.55))
                    Text("Lv. \(stats.level)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("総XP")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(stats.totalXP)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(SplatTheme.yellow)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stats.level < 100 ? "次のレベルまで" : "MAX LEVEL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(stats.level < 100 ? "\(stats.xpInLevel) / \(stats.xpToNext) XP" : "MAX")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white.opacity(0.55))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08)).frame(height: 8)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [SplatTheme.yellow, SplatTheme.magenta],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * stats.xpProgress), height: 8)
                            .shadow(color: SplatTheme.yellow.opacity(0.6), radius: 4)
                    }
                }
                .frame(height: 8)
            }

            if stats.streak >= 2 {
                HStack(spacing: 6) {
                    Text("🔥")
                    Text("\(stats.streak)連続複勝中！")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.12))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(20)
        .background(SplatTheme.card)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Ticket Card

    private var ticketCard: some View {
        Button { showTickets = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(SplatTheme.cyan.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 20))
                        .foregroundColor(SplatTheme.cyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("馬券管理")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                    if tickets.isEmpty {
                        Text("馬券をスキャンして収支を管理")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    } else {
                        HStack(spacing: 10) {
                            Text("¥\(ticketSpent) 投資")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("¥\(ticketReturn) 回収")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(SplatTheme.cyan.opacity(0.9))
                            let n = ticketNet
                            Text((n >= 0 ? "+" : "") + "¥\(n)")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(n >= 0 ? SplatTheme.yellow : .red.opacity(0.8))
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(SplatTheme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(ScalePressStyle())
    }

    // MARK: - Ticket Bet Breakdown

    private var ticketBetBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "ticket.fill")
                    .foregroundColor(SplatTheme.cyan.opacity(0.7))
                    .font(.system(size: 13))
                Text("券種別 的中・回収率")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
            }
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

            if stats.ticketBetStats.isEmpty {
                Text("馬券を追加すると\n買い目パターンが分析されます")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                let sorted = stats.ticketBetStats.sorted { $0.value.total > $1.value.total }
                ForEach(sorted, id: \.key) { betType, stat in
                    ticketBetRow(betType: betType, stat: stat)
                }
            }
        }
        .padding(20)
        .background(SplatTheme.card)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func ticketBetRow(betType: String, stat: PlayerStats.TicketBetStat) -> some View {
        HStack(spacing: 10) {
            Text(betType)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(SplatTheme.cyan)
                .frame(width: 64, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.06)).frame(height: 5)
                        Capsule()
                            .fill(stat.hitRate > 0 ? SplatTheme.yellow : Color.clear)
                            .frame(width: max(0, geo.size.width * CGFloat(min(stat.hitRate, 1.0))), height: 5)
                            .shadow(color: SplatTheme.yellow.opacity(0.5), radius: 3)
                    }
                }
                .frame(height: 5)

                HStack(spacing: 4) {
                    Text("\(stat.hits)/\(stat.total)的中")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.2))
                    let rr = stat.returnRate * 100
                    Text(stat.invested > 0 ? String(format: "回収%.0f%%", rr) : "—")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(rr >= 100 ? SplatTheme.yellow : .white.opacity(0.4))
                }
            }

            Spacer()

            Text(stat.total > 0 ? String(format: "%.0f%%", stat.hitRate * 100) : "—")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - AI Summary Row

    private var summaryRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                Text("AI予想履歴")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(1)
                Spacer()
            }
            HStack(spacing: 12) {
                summaryChip(label: "AI予想数", value: "\(stats.totalPredictions)回")
                summaryChip(label: "複勝数", value: "\(stats.hitCount)/\(stats.resolvedCount)回")
                summaryChip(label: "複勝率", value: stats.resolvedCount > 0 ? String(format: "%.0f%%", stats.hitRate * 100) : "—")
            }
            if stats.pendingCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    Text("結果待ち \(stats.pendingCount)件（レース前・結果未取得）")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                }
            }
        }
    }

    private func summaryChip(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(SplatTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Type Breakdown

    private var typeBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 13))
                Text("予想タイプ別")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
            }
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

            ForEach(PredictionType.allCases, id: \.self) { type in
                let s = stats.typeStats[type.rawValue] ?? PlayerStats.TypeStat(total: 0, hits: 0)
                typeRow(type: type, stat: s)
            }
        }
        .padding(20)
        .background(SplatTheme.card)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func typeRow(type: PredictionType, stat: PlayerStats.TypeStat) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image("HorseIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .colorMultiply(type.color)
                    .brightness(0.15)
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(type.color)
            }
            .frame(width: 90, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06)).frame(height: 6)
                    Capsule()
                        .fill(type.color)
                        .frame(width: max(6, geo.size.width * stat.rate), height: 6)
                        .shadow(color: type.color.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 6)

            Text(stat.total > 0 ? String(format: "%.0f%%", stat.rate * 100) : "—")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 40, alignment: .trailing)

            Text("\(stat.hits)/\(stat.total)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 38, alignment: .trailing)
        }
    }
}

#Preview {
    MyPageView()
        .modelContainer(for: PredictionRecord.self, inMemory: true)
}
