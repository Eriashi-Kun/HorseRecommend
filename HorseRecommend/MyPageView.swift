import SwiftUI
import SwiftData

struct MyPageView: View {
    @Query(sort: \PredictionRecord.savedAt, order: .reverse) private var records: [PredictionRecord]
    @Environment(\.dismiss) private var dismiss

    private var stats: PlayerStats { PlayerStats(records: records) }

    var body: some View {
        ZStack {
            SplatTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        levelCard
                        summaryRow
                        typeBreakdownCard
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
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

    // MARK: - Summary Row

    private var summaryRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                summaryChip(label: "総予想数", value: "\(stats.totalPredictions)回")
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
