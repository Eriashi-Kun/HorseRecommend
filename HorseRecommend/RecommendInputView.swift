import SwiftUI

enum RecommendMode: String, CaseIterable {
    case safe = "固め"
    case balanced = "中穴"
    case romantic = "ロマン"

    var emoji: String {
        switch self {
        case .safe: return "🎯"
        case .balanced: return "⚡"
        case .romantic: return "🔥"
        }
    }

    var description: String {
        switch self {
        case .safe: return "当たりやすさ重視"
        case .balanced: return "バランス"
        case .romantic: return "高配当狙い"
        }
    }
}

struct TicketType: Identifiable {
    let id: String
    let label: String
    let description: String
}

struct RecommendInputView: View {
    @State private var race: Race
    @State private var selectedMode: RecommendMode = .balanced

    init(race: Race) {
        _race = State(initialValue: race)
    }
    @State private var budget = "1000"
    @State private var selectedTickets: Set<String> = ["wide", "quinella"]
    @State private var pivotHorse: Horse? = nil
    @State private var showRaceSelection = false
    @State private var navigateToResult = false

    let ticketTypes = [
        TicketType(id: "win", label: "単勝", description: "1着を当てる"),
        TicketType(id: "place", label: "複勝", description: "3着以内で当たり"),
        TicketType(id: "wide", label: "ワイド", description: "2頭が3着以内で当たり（当たりやすい）"),
        TicketType(id: "quinella", label: "馬連", description: "1着と2着の組み合わせ"),
        TicketType(id: "exacta",   label: "馬単",  description: "1着と2着を順番通り（中配当）"),
        TicketType(id: "trio", label: "三連複", description: "1〜3着を当てる（順不同）"),
        TicketType(id: "trifecta", label: "三連単", description: "1〜3着を順番通り（高配当）")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    // レース情報カード（タップ可能）
                    Button(action: { showRaceSelection = true }) {
                        RaceInfoCard(race: race)
                    }
                    .buttonStyle(PlainButtonStyle())

                    ModeSelectionSection(selectedMode: $selectedMode)
                    BudgetInputSection(budget: $budget)
                    TicketSettingSection(
                        selectedTickets: $selectedTickets,
                        ticketTypes: ticketTypes
                    )

                    // 軸馬選択
                    PivotHorseSection(horses: race.horses, selectedHorse: $pivotHorse)

                    // 初心者向けヒント
                    BeginnerHintCard()

                    Spacer().frame(height: 100)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.05), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // 生成ボタン（固定）
            VStack(spacing: 0) {
                Divider()
                    .background(Color.purple.opacity(0.2))

                Button(action: { navigateToResult = true }) {
                    Text("✨ あなたの買い目を生成する")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.36, green: 0.51, blue: 1.0), Color(red: 0.58, green: 0.38, blue: 0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .purple.opacity(0.3), radius: 12, y: 6)
                }
                .padding()
                .background(Color.white)
            }
        }
        .navigationTitle("買い目レコメンド 🏇")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToResult) {
            ResultView(
                race: race,
                mode: selectedMode,
                budget: Int(budget) ?? 1000,
                selectedTickets: selectedTickets,
                pivotHorse: pivotHorse
            )
        }
        .sheet(isPresented: $showRaceSelection) {
            NavigationStack {
                RaceSelectionView { selectedRace in
                    race = selectedRace
                    pivotHorse = nil
                }
            }
        }
    }
}

// MARK: - レース情報カード
struct RaceInfoCard: View {
    let race: Race

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("🏟️ \(race.venue)")
                    .font(.system(size: 15, weight: .bold))
                Text(race.raceNumber)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.36, green: 0.51, blue: 1.0), Color(red: 0.58, green: 0.38, blue: 0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Text(race.name)
                .font(.system(size: 16, weight: .bold))

            HStack(spacing: 12) {
                Text(race.distance)
                Circle()
                    .fill(Color.purple.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(race.condition)
                Circle()
                    .fill(Color.purple.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text("\(race.time)発走")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white, Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.purple.opacity(0.1), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

// MARK: - モード選択
struct ModeSelectionSection: View {
    @Binding var selectedMode: RecommendMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("モード選択")
                .font(.system(size: 14, weight: .bold))

            HStack(spacing: 10) {
                ForEach(RecommendMode.allCases, id: \.self) { mode in
                    Button(action: { selectedMode = mode }) {
                        VStack(spacing: 8) {
                            // 馬アイコンを表示
                            Group {
                                switch mode {
                                case .safe: SafeHorse()
                                case .balanced: BalancedHorse()
                                case .romantic: RomanticHorse()
                                }
                            }
                            .frame(width: 32, height: 32)

                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                            Text(mode.description)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            selectedMode == mode
                                ? Color.purple.opacity(0.1)
                                : Color.white
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    selectedMode == mode
                                        ? Color.purple
                                        : Color.gray.opacity(0.2),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: .black.opacity(selectedMode == mode ? 0.1 : 0.05),
                            radius: selectedMode == mode ? 8 : 4,
                            y: 2
                        )
                        .scaleEffect(selectedMode == mode ? 1.05 : 1.0)
                    }
                    .animation(.spring(response: 0.3), value: selectedMode)
                }
            }
        }
    }
}

// MARK: - 予算入力
struct BudgetInputSection: View {
    @Binding var budget: String
    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        guard let v = Int(budget), v >= 100 else { return false }
        return v % 100 == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💰 予算")
                .font(.system(size: 14, weight: .bold))

            TextField("1000", text: $budget)
                .keyboardType(.numberPad)
                .font(.system(size: 18, weight: .bold))
                .focused($isFocused)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.white, Color.purple.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused ? Color.purple.opacity(0.5) : (isValid ? Color.purple.opacity(0.2) : Color.red.opacity(0.5)),
                            lineWidth: 2
                        )
                )
                .overlay(
                    Text("円")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 20),
                    alignment: .trailing
                )
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完了") {
                            roundToHundred()
                            isFocused = false
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.purple)
                    }
                }
                .onChange(of: isFocused) { focused in
                    if !focused { roundToHundred() }
                }

            if !isValid && !isFocused && !budget.isEmpty {
                Text("100円単位で入力してください")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }

    private func roundToHundred() {
        guard let value = Int(budget) else {
            budget = "1000"
            return
        }
        budget = "\(max(100, Int((Double(value) / 100).rounded()) * 100))"
    }
}

// MARK: - 券種設定
struct TicketSettingSection: View {
    @Binding var selectedTickets: Set<String>
    let ticketTypes: [TicketType]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎫 券種設定")
                    .font(.system(size: 14, weight: .bold))
                Text("複数選択可")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
            }

            VStack(spacing: 8) {
                ForEach(ticketTypes) { ticket in
                    TicketCheckbox(
                        ticket: ticket,
                        isSelected: selectedTickets.contains(ticket.id)
                    ) {
                        if selectedTickets.contains(ticket.id) {
                            selectedTickets.remove(ticket.id)
                        } else {
                            selectedTickets.insert(ticket.id)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

struct TicketCheckbox: View {
    let ticket: TicketType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // カスタムチェックボックス
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.purple : Color.white)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ticket.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)

                    Text(ticket.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(12)
            .background(
                isSelected
                    ? LinearGradient(
                        colors: [Color.purple.opacity(0.05), Color.indigo.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(colors: [Color.white, Color.white], startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 2)
            )
            .shadow(color: .black.opacity(isSelected ? 0.05 : 0.02), radius: isSelected ? 4 : 2, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 軸馬選択
struct PivotHorseSection: View {
    let horses: [Horse]
    @Binding var selectedHorse: Horse?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🐴 軸馬選択（任意）")
                        .font(.system(size: 14, weight: .bold))
                    Text("1頭選ぶと、より精度の高い買い目になります")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selectedHorse != nil {
                    Button(action: { selectedHorse = nil }) {
                        Text("解除")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(horses.sorted { $0.number < $1.number }) { horse in
                    HorseBadgeButton(
                        horse: horse,
                        isSelected: selectedHorse?.id == horse.id,
                        onTap: { selectedHorse = selectedHorse?.id == horse.id ? nil : horse }
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    selectedHorse != nil ? Color.purple.opacity(0.4) : Color.gray.opacity(0.15),
                    lineWidth: selectedHorse != nil ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

struct HorseBadgeButton: View {
    let horse: Horse
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? Color.purple : Color.gray.opacity(0.1))
                    .overlay(Circle().stroke(
                        isSelected ? Color.purple : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 0 : 1
                    ))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("\(horse.number)")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(isSelected ? .white : .primary)
                    )
                    .overlay(
                        Text(horse.runningStyle.rawValue)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(horse.runningStyle.color)
                            .cornerRadius(4),
                        alignment: .topTrailing
                    )
                    .shadow(color: isSelected ? Color.purple.opacity(0.3) : .clear, radius: 6, y: 2)

                Text(horse.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .purple : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - 初心者向けヒント
struct BeginnerHintCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("💡")
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 4) {
                Text("初めての方へ")
                    .font(.system(size: 13, weight: .bold))

                Text("迷ったら")
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.8))
                + Text("固め × ワイド＋馬連")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.13, green: 0.55, blue: 0.13))
                + Text("がおすすめです")
                    .font(.system(size: 12))
                    .foregroundColor(.primary.opacity(0.8))
            }

            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.96, blue: 0.4), Color(red: 1.0, green: 0.93, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 1.0, green: 0.9, blue: 0.3), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}
