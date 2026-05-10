import SwiftUI

struct PredictionTypeSelectView: View {
    @State private var selected: PredictionType = .safe
    @State private var race: Race = MockRaceRepository().fetchCurrentRace()
    @State private var allRaces: [Race] = sampleRaces
    @State private var isLoadingRaces = false
    @State private var navigate = false
    @State private var showRaceSelection = false

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
                NavigationStack {
                    RaceSelectionView(races: allRaces, onSelect: { r in race = r })
                }
                .preferredColorScheme(.dark)
            }
            .navigationDestination(isPresented: $navigate) {
                RecommendationResultView(type: selected, race: race)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: -10) {
                Text("PICK")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(selected.color)
                    .shadow(color: selected.color.opacity(0.7), radius: 16, y: 0)
                    .rotationEffect(.degrees(-2))
                Text("YOUR TYPE")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.80))
                    .padding(.leading, 4)
            }
            Spacer()
            Text(selected.emoji)
                .font(.system(size: 44))
                .rotationEffect(.degrees(14))
                .shadow(color: selected.color.opacity(0.6), radius: 10)
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 16)
    }

    // MARK: - Race Bar (tap to change race)

    private var raceBar: some View {
        Button(action: { showRaceSelection = true }) {
            HStack(spacing: 10) {
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
            race = network.currentRace(from: races)
        } catch {
            // ネットワーク失敗時はモックデータのまま継続
            print("Race load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Go Button

    private var goButton: some View {
        let past = race.isPast
        return Button { if !past { navigate = true } } label: {
            Text(past ? "レース終了" : "予想スタート！")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(past ? .white.opacity(0.35) : SplatTheme.bg)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SplatButtonStyle(color: past ? Color.gray.opacity(0.3) : selected.color, height: 64))
        .disabled(past)
        .padding(.horizontal, 20)
        .padding(.bottom, 48)
        .animation(.easeInOut(duration: 0.3), value: selected)
        .animation(.easeInOut(duration: 0.2), value: past)
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

                // Emoji badge — decoration gets the tilt
                ZStack {
                    Circle()
                        .fill(type.color)
                        .frame(width: 58, height: 58)
                        .shadow(color: type.color.opacity(isSelected ? 0.70 : 0.28),
                                radius: isSelected ? 14 : 5)
                    Text(type.emoji)
                        .font(.system(size: 28))
                }
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
        .scaleEffect(isSelected ? 1.03 : 1.0)
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
