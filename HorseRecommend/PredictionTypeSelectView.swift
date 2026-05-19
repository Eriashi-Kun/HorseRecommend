import SwiftUI

struct PredictionTypeSelectView: View {
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
    @State private var showAdPrompt = false
    @State private var showAdFailedAlert = false
    @State private var pendingVM: RecommendationViewModel = RecommendationViewModel()
    @Environment(UserWeightsManager.self) private var weights
    @Environment(RewardedAdManager.self) private var adManager

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
            }
            .animation(.easeInOut(duration: 0.5), value: selected)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadRaces() }
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
            .navigationDestination(isPresented: $navigate) {
                RecommendationResultView(type: selected, race: race, vm: pendingVM)
            }
            .alert("本日の無料予想を使い切りました", isPresented: $showAdPrompt) {
                Button("広告を視聴して予想する") {
                    adManager.showAd(
                        onRewarded: {
                            adManager.incrementCount()
                            navigate = true
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
                    customizeButton
                }
            }

            Spacer()

            Image("HorseIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .colorMultiply(selected.color)
                .brightness(0.15)
                .shadow(color: selected.color.opacity(0.7), radius: 12)
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
            .foregroundColor(weights.isCustomized ? SplatTheme.magenta : .white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(weights.isCustomized ? SplatTheme.magenta.opacity(0.15) : SplatTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                weights.isCustomized ? SplatTheme.magenta.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
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
