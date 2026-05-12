import SwiftUI

// MARK: - Share Card (SNSシェア用の画像カード)

struct ShareCardView: View {
    let rec: Recommendation
    let type: PredictionType

    private var rankLabel: String {
        switch rec.score {
        case 85...: return "S"
        case 70...: return "A"
        case 55...: return "B"
        case 40...: return "C"
        default:    return "D"
        }
    }

    private var rankColor: Color {
        switch rec.score {
        case 85...: return Color(red: 1.00, green: 0.02, blue: 0.65)
        case 70...: return Color(red: 1.00, green: 0.88, blue: 0.00)
        case 55...: return Color(red: 0.00, green: 0.95, blue: 1.00)
        case 40...: return Color(red: 0.72, green: 0.00, blue: 1.00)
        default:    return .gray
        }
    }

    var body: some View {
        ZStack {
            // 背景
            SplatTheme.bg

            // タイプカラーのグロー
            RadialGradient(
                colors: [type.color.opacity(0.18), .clear],
                center: .center, startRadius: 0, endRadius: 260
            )

            // コーナーアクセント
            VStack {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(type.color.opacity(0.6))
                        .frame(width: 40, height: 4)
                        .padding(.top, 0)
                        .padding(.trailing, 24)
                }
                Spacer()
            }

            VStack(spacing: 0) {
                headerRow
                Spacer()
                horseSection
                Spacer()
                scoreSection
                Spacer(minLength: 12)
                badgeRow
                Spacer(minLength: 16)
                footerRow
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 360, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [type.color.opacity(0.7), type.color.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text("HORSE RECOMMEND")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.28))
                .tracking(2.5)
            Spacer()
            HStack(spacing: 5) {
                Text(type.emoji).font(.system(size: 13))
                Text(type.rawValue + " 予想")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(type.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(type.color.opacity(0.15))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(type.color.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Horse

    private var horseSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(type.color)
                    .frame(width: 88, height: 88)
                    .shadow(color: type.color.opacity(0.75), radius: 22)
                    .overlay(
                        Text("\(rec.horse.number)")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundColor(SplatTheme.bg)
                    )
                Text(rankLabel)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(SplatTheme.bg)
                    .frame(width: 28, height: 28)
                    .background(rankColor)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .shadow(color: rankColor.opacity(0.8), radius: 5)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.25), lineWidth: 1))
                    .offset(x: 8, y: -5)
            }
            .rotationEffect(.degrees(-4))

            Text(rec.horse.name)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: type.color.opacity(0.45), radius: 14)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(spacing: 10) {
                Label("\(rec.popularityRank)番人気", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(type.color)
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 13)
                Text("オッズ \(String(format: "%.1f", rec.horse.odds))倍")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Score

    private var scoreSection: some View {
        HStack(spacing: 6) {
            Text("SCORE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.28))
                .tracking(2)
                .padding(.top, 14)
            Text("\(Int(rec.score))")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundColor(type.color)
                .shadow(color: type.color.opacity(0.65), radius: 10)
            Text("/ 99")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.28))
                .padding(.top, 22)
        }
    }

    // MARK: - Badges

    private var badgeRow: some View {
        HStack(spacing: 6) {
            ForEach(HorseTrait.compute(rec: rec).prefix(3), id: \.self) { trait in
                HStack(spacing: 4) {
                    Image(systemName: trait.icon).font(.system(size: 9, weight: .black))
                    Text(trait.label).font(.system(size: 10, weight: .black))
                }
                .foregroundColor(SplatTheme.bg)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(trait.color)
                .cornerRadius(16)
                .shadow(color: trait.color.opacity(0.5), radius: 3)
            }
            Spacer()
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.race.name)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                Text("\(rec.race.venue)  \(rec.race.distance)  馬場:\(rec.race.condition)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            Spacer()
            Text("🐴")
                .font(.system(size: 18))
                .opacity(0.5)
        }
        .padding(.top, 12)
        .overlay(Rectangle().fill(.white.opacity(0.07)).frame(height: 1), alignment: .top)
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
