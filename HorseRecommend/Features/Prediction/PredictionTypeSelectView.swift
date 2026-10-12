import SwiftUI
import SwiftData

struct PredictionTypeSelectView: View {
    @Query private var records: [PredictionRecord]
    private var stats: PlayerStats { PlayerStats(records: records) }

    @State private var selected: PredictionType = .safe
    @State private var race: Race = MockRaceRepository().fetchCurrentRace()
    @State private var allRaces: [Race] = sampleRaces
    @State private var isLoadingRaces = false
    @State private var racesLoaded = false
    @State private var navigate = false
    @State private var showRaceSelection = false
    @State private var showCustomize = false
    @State private var raceManuallySelected = false
    @State private var isNavigating = false
    @State private var showHistory = false
    @State private var showMyPage = false
    @State private var showAdPrompt = false
    @State private var xpGainAmount: Int? = nil
    @State private var snapshotLevel: Int = 0
    @State private var snapshotXP: Int = 0
    @State private var showTransitionLoader = false
    @State private var showAdFailedAlert = false
    @State private var pendingVM: RecommendationViewModel = RecommendationViewModel()
    @State private var hitBannerXP: Int? = nil
    @Environment(UserWeightsManager.self) private var weights
    @Environment(RewardedAdManager.self) private var adManager
    @Environment(\.modelContext) private var modelContext

    private let network = NetworkRaceRepository()

    var body: some View {
        NavigationStack {
            ZStack {
                InkBlobBackground(primaryColor: selected.color)

                VStack(spacing: 0) {
                    header
                    raceBar
                    Spacer()
                    typeCards
                    Spacer(minLength: 24)
                    goButton
                }

                if let xp = hitBannerXP {
                    VStack {
                        HStack(spacing: 12) {
                            Text("🏆")
                                .font(.system(size: 26))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("複勝的中！")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundColor(.white)
                                Text("+\(xp) XP 獲得！")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(SplatTheme.yellow)
                                    .shadow(color: SplatTheme.yellow.opacity(0.7), radius: 4)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 56)
                        .padding(.bottom, 14)
                        .background(SplatTheme.card)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(SplatTheme.yellow.opacity(0.6)).frame(height: 2)
                        }
                        Spacer()
                    }
                    .ignoresSafeArea()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if showTransitionLoader {
                    ZStack {
                        SplatTheme.bg.ignoresSafeArea()
                        InkBlobBackground(primaryColor: selected.color)
                        VStack(spacing: 16) {
                            ProgressView().tint(selected.color).scaleEffect(1.4)
                            Text("AI予想を生成中...")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .animation(.easeInOut(duration: 0.5), value: selected)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hitBannerXP)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                async let r: () = loadRaces()
                async let p: () = fetchPendingResults()
                _ = await (r, p)
            }
            .sheet(isPresented: $showRaceSelection) {
                RaceSelectionView(races: allRaces, onSelect: { r in
                    race = r
                    raceManuallySelected = true
                })
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showCustomize) {
                ParameterCustomizeView()
                    .environment(weights)
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showMyPage) {
                MyPageView()
            }
            .navigationDestination(isPresented: $navigate) {
                RecommendationResultView(type: selected, race: race, vm: pendingVM)
            }
            .onChange(of: navigate) { _, isNavigating in
                guard !isNavigating else { return }
                showTransitionLoader = false
                let gained = stats.totalXP - snapshotXP
                guard gained > 0 else { return }

                // +XP 表示
                xpGainAmount = gained
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { xpGainAmount = nil }
                }

                // サウンドフィードバック
                let oldTitle = PlayerStats.title(for: snapshotLevel)
                let newTitle = PlayerStats.title(for: stats.level)
                if stats.level > snapshotLevel && newTitle != oldTitle {
                    SoundManager.playTitleUp()
                } else if stats.level > snapshotLevel {
                    SoundManager.playLevelUp()
                } else {
                    SoundManager.playXPGain()
                }
            }
            .alert("本日の無料予想を使い切りました", isPresented: $showAdPrompt) {
                Button("広告を視聴して予想する") {
                    adManager.showAd(
                        onRewarded: {
                            showTransitionLoader = true
                            adManager.incrementCount()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigate = true
                            }
                        },
                        onFailed: { showAdFailedAlert = true }
                    )
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("広告を1本視聴すると、もう1回予想できます。")
            }
            .alert("広告を読み込めませんでした", isPresented: $showAdFailedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("しばらくしてからもう一度お試しください。")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左側: PAKAPICK + ボタン群
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: -10) {
                    Text("PAKA")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(selected.color)
                        .shadow(color: selected.color.opacity(0.7), radius: 16, y: 0)
                    Text("PICK")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.80))
                        .padding(.leading, 4)
                }
                HStack(spacing: 8) {
                    if stats.streak >= 2 {
                        HStack(spacing: 3) {
                            Text("🔥")
                                .font(.system(size: 11))
                            Text("\(stats.streak)連続")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    Button {
                        showHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13, weight: .bold))
                            Text("履歴")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScalePressStyle())
                    customizeButton
                }
            }

            Spacer()

            // 右側: マイページ + Lv + XPバー
            VStack(alignment: .trailing, spacing: 8) {
                Button(action: { showMyPage = true }) {
                    VStack(spacing: 5) {
                        Image("HorseIcon")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .colorMultiply(selected.color)
                            .brightness(0.15)
                            .shadow(color: selected.color.opacity(0.6), radius: 8)
                        Text("マイページ")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(selected.color)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(selected.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected.color.opacity(0.45), lineWidth: 1.5)
                    )
                }
                .buttonStyle(ScalePressStyle())

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 5) {
                        Text("Lv.\(stats.level)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(selected.color)
                        Text(stats.title)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.1)).frame(height: 4)
                            Capsule()
                                .fill(selected.color)
                                .frame(width: max(4, geo.size.width * stats.xpProgress), height: 4)
                                .shadow(color: selected.color.opacity(0.6), radius: 3)
                        }
                    }
                    .frame(width: 80, height: 4)
                    .overlay(alignment: .trailing) {
                        if let gained = xpGainAmount {
                            Text("+\(gained) XP")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(selected.color)
                                .shadow(color: selected.color.opacity(0.8), radius: 4)
                                .offset(y: -14)
                                .transition(.asymmetric(
                                    insertion: .offset(y: 4).combined(with: .opacity),
                                    removal: .offset(y: -8).combined(with: .opacity)
                                ))
                        }
                    }
                    .animation(.easeOut(duration: 0.6), value: xpGainAmount)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }

    private var customizeButton: some View {
        Button(action: { showCustomize = true }) {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .black))
                Text("カスタマイズ")
                    .font(.system(size: 11, weight: .black))
                if weights.isCustomized {
                    Circle()
                        .fill(SplatTheme.magenta)
                        .frame(width: 6, height: 6)
                        .shadow(color: SplatTheme.magenta, radius: 3)
                }
            }
            .foregroundColor(weights.isCustomized ? SplatTheme.magenta : .white.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(weights.isCustomized ? SplatTheme.magenta.opacity(0.18) : .white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(weights.isCustomized ? SplatTheme.magenta.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressStyle())
    }

    // MARK: - Race Bar (tap to change race)

    private var raceBar: some View {
        Button(action: { if racesLoaded { showRaceSelection = true } }) {
            HStack(spacing: 10) {
                if !racesLoaded && isLoadingRaces {
                    ProgressView()
                        .tint(selected.color)
                        .scaleEffect(0.8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("レースデータを取得中...")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                        Text("初回は約1分かかります")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.38))
                    }
                    Spacer()
                } else {
                    if race.showsGradeBadge {
                        Text(race.grade.displayText)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(SplatTheme.bg)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(race.grade.color)
                            .cornerRadius(5)
                    }
                    Text(race.venue)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white.opacity(0.55))
                    Text(race.raceNumber)
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white.opacity(0.55))
                    Text(race.name)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(race.time)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selected.color)
                    if isLoadingRaces {
                        ProgressView()
                            .tint(selected.color)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(SplatTheme.card)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected.color.opacity(0.45), lineWidth: 1.5)
            )
        }
        .buttonStyle(ScalePressStyle())
        .padding(.horizontal, 20)
    }

    // MARK: - Type Cards

    private var typeCards: some View {
        VStack(spacing: 14) {
            ForEach(Array(PredictionType.allCases.enumerated()), id: \.element) { index, type in
                SplatTypeCard(type: type, isSelected: selected == type, index: index)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                            selected = type
                        }
                    }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Network Loading

    private func loadRaces() async {
        isLoadingRaces = true
        defer { isLoadingRaces = false }
        do {
            let races = try await network.fetchRaces()
            allRaces = races
            if !raceManuallySelected {
                race = network.currentRace(from: races)
            }
            racesLoaded = true
        } catch {
            racesLoaded = true  // エラーでもモックデータで続行できるようにする
            print("Race load failed: \(error.localizedDescription)")
        }
    }

    private func fetchPendingResults() async {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyyMMdd"
        let today = dateFmt.string(from: Date())

        let pending = records.filter { record in
            !record.raceId.isEmpty &&
            record.day < today &&
            record.picks.allSatisfy { $0.finishPosition == nil }
        }
        guard !pending.isEmpty else { return }

        var totalHitXP = 0
        for record in pending {
            let result = await network.fetchRaceResult(raceId: record.raceId)
            guard !result.isEmpty else { continue }

            var updated = record.picks
            for i in updated.indices {
                if let pos = result[updated[i].horseNumber] {
                    updated[i].finishPosition = pos
                }
            }
            record.picks = updated

            if let firstPos = updated.first?.finishPosition, (1...3).contains(firstPos) {
                totalHitXP += PlayerStats.xpPerHit
            }
        }
        try? modelContext.save()

        if totalHitXP > 0 {
            await MainActor.run {
                withAnimation { hitBannerXP = totalHitXP }
                SoundManager.playXPGain()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation { hitBannerXP = nil }
                }
            }
        }
    }

    private func refreshAndNavigate() async {
        isNavigating = true
        defer { isNavigating = false }
        if let races = try? await network.fetchRaces() {
            allRaces = races
            if let updated = races.first(where: {
                $0.day == race.day && $0.venue == race.venue && $0.raceNumber == race.raceNumber
            }) {
                race = updated
            }
        }
        // 遷移前のXP・レベルを記録（戻り時の差分検出用）
        snapshotLevel = stats.level
        snapshotXP = stats.totalXP

        // VMを作成してAI先読み開始（広告視聴中・遷移アニメーション中に並行実行）
        let vm = RecommendationViewModel()
        pendingVM = vm
        Task { await vm.load(type: selected, race: race, weights: weights) }

        if adManager.needsAd {
            showAdPrompt = true
        } else {
            adManager.incrementCount()
            navigate = true
        }
    }

    // MARK: - Go Button

    private var goButton: some View {
        let past = race.isPast
        let disabled = past || !racesLoaded || isNavigating
        return Button { if !disabled { Task { await refreshAndNavigate() } } } label: {
            Text(!racesLoaded ? "取得中..." : isNavigating ? "更新中..." : past ? "レース終了" : "予想スタート！")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(disabled ? .white.opacity(0.35) : SplatTheme.bg)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SplatButtonStyle(color: disabled ? Color.gray.opacity(0.3) : selected.color, height: 64))
        .disabled(disabled)
        .padding(.horizontal, 20)
        .padding(.bottom, 48)
        .animation(.easeInOut(duration: 0.3), value: selected)
        .animation(.easeInOut(duration: 0.2), value: past)
        .animation(.easeInOut(duration: 0.2), value: isNavigating)
    }
}

// MARK: - SplatTypeCard

struct SplatTypeCard: View {
    let type: PredictionType
    let isSelected: Bool
    let index: Int

    @State private var shimmerX: CGFloat = -0.3

    var body: some View {
        ZStack {
            // Glow shadow
            RoundedRectangle(cornerRadius: 18)
                .fill(isSelected ? type.color.opacity(0.40) : Color.black.opacity(0.5))
                .offset(x: 4, y: 7)
                .blur(radius: isSelected ? 10 : 3)

            // Card body + shimmer overlay
            RoundedRectangle(cornerRadius: 18)
                .fill(isSelected ? type.color.opacity(0.13) : SplatTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(type.color, lineWidth: isSelected ? 2.5 : 1.0)
                        .opacity(isSelected ? 1.0 : 0.35)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.11), .clear],
                                    startPoint: UnitPoint(x: shimmerX, y: 0.5),
                                    endPoint: UnitPoint(x: shimmerX + 0.4, y: 0.5)
                                )
                            )
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 14) {
                // Left color bar — decoration stays, card stays straight
                RoundedRectangle(cornerRadius: 3)
                    .fill(type.color)
                    .frame(width: 5, height: isSelected ? 54 : 26)
                    .shadow(color: type.color.opacity(0.75), radius: isSelected ? 9 : 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)

                // Horse icon — color shifts per type via colorMultiply
                Image("HorseIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .colorMultiply(type.color)
                    .brightness(0.15)
                    .shadow(color: type.color.opacity(isSelected ? 0.75 : 0.30),
                            radius: isSelected ? 14 : 5)
                    .overlay(
                        Circle()
                            .stroke(type.color, lineWidth: isSelected ? 2.5 : 1.0)
                            .opacity(isSelected ? 0.9 : 0.35)
                    )
                    .rotationEffect(.degrees(-8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(isSelected ? type.color : .white)
                    Text(type.subtitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.40))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.seal.fill" : "seal")
                    .font(.system(size: 26))
                    .foregroundColor(isSelected ? type.color : .white.opacity(0.18))
                    .rotationEffect(.degrees(12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .scaleEffect(1.0)
        .onChange(of: isSelected) { _, newValue in
            guard newValue else { return }
            shimmerX = -0.3
            withAnimation(.easeOut(duration: 0.45)) {
                shimmerX = 1.3
            }
        }
    }
}

#Preview {
    PredictionTypeSelectView()
}
