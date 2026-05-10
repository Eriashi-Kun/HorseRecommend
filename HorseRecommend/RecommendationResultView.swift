import SwiftUI

struct RecommendationResultView: View {
    let type: PredictionType
    let race: Race
    @StateObject private var vm = RecommendationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        ZStack {
            InkBlobBackground(primaryColor: type.color)

            if let rec = vm.current {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        topBar(rec: rec)
                        horseHero(rec: rec)
                        statsRow(rec: rec)
                        reasonCard(rec: rec)
                        infoChips(rec: rec)
                        if vm.hasNext { nextButton }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            } else {
                ProgressView().tint(type.color)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await vm.load(type: type, race: race)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.08)) {
                appeared = true
            }
        }
    }

    // MARK: - Top Bar

    private func topBar(rec: Recommendation) -> some View {
        HStack(spacing: 0) {
            // Custom back button
            Button(action: { dismiss() }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .black))
                    Text("BACK")
                        .font(.system(size: 12, weight: .black))
                }
                .foregroundColor(type.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(type.color.opacity(0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(type.color.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(ScalePressStyle())

            Spacer()

            HStack(spacing: 6) {
                Text(type.emoji).font(.system(size: 16))
                Text(type.rawValue + " 予想")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(type.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(type.color.opacity(0.13))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(type.color.opacity(0.35), lineWidth: 1))
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Horse Hero Card

    private func horseHero(rec: Recommendation) -> some View {
        ZStack {
            // Glow shadow
            RoundedRectangle(cornerRadius: 22)
                .fill(type.color.opacity(0.35))
                .offset(x: 5, y: 9)
                .blur(radius: 12)

            RoundedRectangle(cornerRadius: 22)
                .fill(SplatTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(type.color, lineWidth: 2.5)
                )

            VStack(spacing: 14) {
                // Number badge — tilted sticker style
                ZStack {
                    Circle()
                        .fill(type.color)
                        .frame(width: 82, height: 82)
                        .shadow(color: type.color.opacity(0.75), radius: 18)
                    Text("\(rec.horse.number)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(SplatTheme.bg)
                }
                .rotationEffect(.degrees(-6))
                .padding(.top, 4)

                // Horse name
                Text(rec.horse.name)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: type.color.opacity(0.35), radius: 10)

                // Sub labels
                HStack(spacing: 10) {
                    Label("\(rec.popularityRank)番人気", systemImage: "flame.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(type.color)
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 1, height: 14)
                    Text("オッズ \(String(format: "%.1f", rec.horse.odds))倍")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.bottom, 4)
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 20)
        }
        .scaleEffect(appeared ? 1 : 0.65)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Stats Row

    private func statsRow(rec: Recommendation) -> some View {
        HStack(spacing: 12) {
            scoreGauge(rec: rec)

            VStack(spacing: 10) {
                statChip(label: "人気", value: "\(rec.popularityRank)番人気", color: type.color)
                statChip(label: "オッズ", value: String(format: "%.1f倍", rec.horse.odds), color: .white.opacity(0.65))
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    private func scoreGauge(rec: Recommendation) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(SplatTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(type.color.opacity(0.28), lineWidth: 1))

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(rec.score / 99))
                        .stroke(type.color,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: type.color.opacity(0.65), radius: 7)
                    VStack(spacing: -2) {
                        Text("\(Int(rec.score))")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(type.color)
                        Text("/ 99")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .frame(width: 90, height: 90)

                Text("SCORE")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
            }
            .padding(.vertical, 16)
        }
        .frame(width: 130)
        .frame(maxHeight: .infinity)
    }

    private func statChip(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.white.opacity(0.38))
                .frame(width: 34, alignment: .leading)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SplatTheme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Reason Card

    private func reasonCard(rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(type.color)
                    .font(.system(size: 13))
                Text("REASON")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(type.color)
                    .tracking(2)
            }
            Text(rec.reason)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.80))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SplatTheme.card)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(type.color.opacity(0.22), lineWidth: 1))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // MARK: - Info Chips

    private func infoChips(rec: Recommendation) -> some View {
        HStack(spacing: 10) {
            infoChip(label: "脚質",
                     value: rec.horse.runningStyle.rawValue,
                     color: rec.horse.runningStyle.color)
            infoChip(label: "距離", value: rec.race.distance, color: .white.opacity(0.65))
            infoChip(label: "馬場", value: rec.race.condition, color: .white.opacity(0.65))
        }
        .opacity(appeared ? 1 : 0)
    }

    private func infoChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white.opacity(0.32))
                .tracking(1)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(SplatTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Next Horse Button

    private var nextButton: some View {
        Button {
            withAnimation(.easeIn(duration: 0.14)) { appeared = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                vm.showNext()
                withAnimation(.spring(response: 0.52, dampingFraction: 0.70)) {
                    appeared = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .black))
                Text("別の馬を見る")
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundColor(SplatTheme.bg)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SplatButtonStyle(color: type.color, height: 56))
    }
}

#Preview {
    NavigationStack {
        RecommendationResultView(type: .midRange, race: sampleRaces[0])
    }
}
