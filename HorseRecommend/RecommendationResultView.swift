import SwiftUI

struct RecommendationResultView: View {
    let type: PredictionType
    let race: Race
    @StateObject private var vm = RecommendationViewModel()
    @Environment(InterstitialAdManager.self) private var adManager
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var slotNumber: Int = 0
    @State private var radarProgress: Double = 0
    @State private var shareImage: UIImage? = nil
    @State private var showingShare = false
    @State private var adShown = false

    var body: some View {
        ZStack {
            InkBlobBackground(primaryColor: type.color)

            if let rec = vm.current {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topBar(rec: rec)
                        raceStrip
                        horseHero(rec: rec)
                        statsRow(rec: rec)
                        radarCard(rec: rec)
                        traitBadges(rec: rec)
                        reasonCard(rec: rec)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            } else {
                loadingView
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingShare) {
            if let img = shareImage, let rec = vm.current {
                ShareSheet(items: [img, shareText(rec: rec)])
                    .presentationDetents([.medium, .large])
            }
        }
        .task {
            await vm.load(type: type, race: race)
            if !adShown {
                adShown = true
                adManager.showIfNeeded(raceID: "\(race.day)-\(race.venue)-\(race.raceNumber)")
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.08)) {
                appeared = true
            }
            if let rec = vm.current {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await animateSlot(target: rec.horse.number)
                withAnimation(.easeOut(duration: 0.65)) { radarProgress = 1.0 }
            }
        }
        .onChange(of: vm.currentIndex) { _, _ in
            radarProgress = 0
            slotNumber = 0
            guard let rec = vm.current else { return }
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await animateSlot(target: rec.horse.number)
                withAnimation(.easeOut(duration: 0.65)) { radarProgress = 1.0 }
            }
        }
    }

    // MARK: - Slot Animation

    @MainActor
    private func animateSlot(target: Int) async {
        let delays: [UInt64] = [45, 45, 50, 55, 65, 80, 100, 130, 170, 220, 280, 350]
        for (i, delay) in delays.enumerated() {
            slotNumber = i < delays.count - 1 ? Int.random(in: 1...18) : target
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
        }
        slotNumber = target
    }

    // MARK: - Share Text

    private func shareText(rec: Recommendation) -> String {
        let (rank, _) = rankInfo(score: rec.score)
        let score = Int(rec.score)
        let name = rec.horse.name
        switch type {
        case .safe:
            return "🎯 本命確信！\(name)で堅く行くぜ！\nスコア\(score)/99  RANK \(rank)\n#Pakapick #競馬予想"
        case .midRange:
            return "⚡ 中穴狙い撃ち！\(name)が激走する！\nスコア\(score)/99  RANK \(rank)\n#Pakapick #競馬予想"
        case .longShot:
            return "🔥 爆穴炸裂！\(name)で万馬券を狙え！\nスコア\(score)/99  RANK \(rank)\n#Pakapick #競馬予想"
        }
    }

    // MARK: - Rank

    private func rankInfo(score: Double) -> (String, Color) {
        switch score {
        case 85...: return ("S", Color(red: 1.00, green: 0.02, blue: 0.65))
        case 70...: return ("A", Color(red: 1.00, green: 0.88, blue: 0.00))
        case 55...: return ("B", Color(red: 0.00, green: 0.95, blue: 1.00))
        case 40...: return ("C", Color(red: 0.72, green: 0.00, blue: 1.00))
        default:    return ("D", .gray)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(type.color).scaleEffect(1.4)
            Text("AI予想を生成中...")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Top Bar

    private func topBar(rec: Recommendation) -> some View {
        HStack(spacing: 8) {
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

            // シェアボタン
            Button {
                shareImage = renderShareCard(rec: rec)
                showingShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(type.color)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(type.color.opacity(0.15))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(type.color.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(ScalePressStyle())

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

    @MainActor
    private func renderShareCard(rec: Recommendation) -> UIImage? {
        let card = ShareCardView(rec: rec, type: type)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    // MARK: - Race Strip

    private var raceStrip: some View {
        HStack(spacing: 8) {
            if race.showsGradeBadge {
                Text(race.grade.displayText)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(SplatTheme.bg)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(race.grade.color)
                    .cornerRadius(4)
            }
            Text(race.venue)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.white.opacity(0.5))
            Text(race.name)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
            Spacer()
            Text(race.distance)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
            Text("·")
                .foregroundColor(.white.opacity(0.2))
            Text(race.condition)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SplatTheme.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Horse Hero Card

    private func horseHero(rec: Recommendation) -> some View {
        let (rankLabel, rankColor) = rankInfo(score: rec.score)
        return ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(type.color.opacity(0.35))
                .offset(x: 5, y: 9)
                .blur(radius: 12)

            RoundedRectangle(cornerRadius: 22)
                .fill(SplatTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(type.color, lineWidth: 2.5))

            VStack(spacing: 14) {
                // 馬番（スロット）+ ランクバッジ
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(type.color)
                            .frame(width: 82, height: 82)
                            .shadow(color: type.color.opacity(0.75), radius: 18)
                        Text(slotNumber == 0 ? "?" : "\(slotNumber)")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(SplatTheme.bg)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.06), value: slotNumber)
                    }
                    // ランクバッジ
                    Text(rankLabel)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(SplatTheme.bg)
                        .frame(width: 30, height: 30)
                        .background(rankColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: rankColor.opacity(0.8), radius: 6)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.3), lineWidth: 1))
                        .offset(x: 10, y: -6)
                }
                .rotationEffect(.degrees(-6))
                .padding(.top, 4)

                Text(rec.horse.name)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: type.color.opacity(0.35), radius: 10)

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
        let (rankLabel, rankColor) = rankInfo(score: rec.score)
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(SplatTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(type.color.opacity(0.28), lineWidth: 1))

            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(rec.score / 99))
                        .stroke(type.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: type.color.opacity(0.65), radius: 7)
                    VStack(spacing: -2) {
                        Text("\(Int(rec.score))")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(type.color)
                        Text("/ 99")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .frame(width: 90, height: 90)

                // ランク表示
                Text("RANK  \(rankLabel)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(rankColor)
                    .tracking(1)
                    .shadow(color: rankColor.opacity(0.6), radius: 4)
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

    // MARK: - Radar Card

    private func radarCard(rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(type.color)
                    .font(.system(size: 13))
                Text("パラメータ")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(type.color)
                    .tracking(1)
                Spacer()
            }
            Rectangle()
                .fill(type.color.opacity(0.25))
                .frame(height: 1)

            HStack {
                Spacer()
                RadarChartView(
                    params: HorseParameters.compute(rec: rec),
                    color: type.color,
                    size: 230,
                    progress: radarProgress
                )
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(SplatTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [type.color.opacity(0.45), type.color.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // MARK: - Trait Badges

    private func traitBadges(rec: Recommendation) -> some View {
        let traits = HorseTrait.compute(rec: rec)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(traits, id: \.self) { trait in
                    HStack(spacing: 5) {
                        Image(systemName: trait.icon)
                            .font(.system(size: 10, weight: .black))
                        Text(trait.label)
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundColor(SplatTheme.bg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(trait.color)
                    .cornerRadius(20)
                    .shadow(color: trait.color.opacity(0.55), radius: 5)
                }
            }
            .padding(.horizontal, 1)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    // MARK: - Reason Card

    private func reasonCard(rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(type.color)
                    .font(.system(size: 14))
                Text("予想理由")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(type.color)
                    .tracking(1)
                Spacer()
            }
            Rectangle()
                .fill(type.color.opacity(0.25))
                .frame(height: 1)
            Text(rec.reason)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(SplatTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [type.color.opacity(0.5), type.color.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // MARK: - Next Button

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
