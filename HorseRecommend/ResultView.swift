import SwiftUI

// MARK: - Models

enum BuyingStyle {
    case single([Horse])
    case nagashi(axis: [Horse], opponents: [Horse])
    case box(horses: [Horse])
    case formation(first: [Horse], second: [Horse], third: [Horse])

    var label: String {
        switch self {
        case .single:    return ""
        case .nagashi:   return "流し"
        case .box:       return "ボックス"
        case .formation: return "フォーメーション"
        }
    }
}

struct BettingInstruction: Identifiable {
    let id = UUID()
    let ticketLabel: String
    let style: BuyingStyle
    let combinationCount: Int
    var amountPerCombination: Int = 100
    var totalAmount: Int { combinationCount * amountPerCombination }
}

// MARK: - ResultView

struct ResultView: View {
    let race: Race
    let mode: RecommendMode
    let budget: Int
    let selectedTickets: Set<String>
    let pivotHorse: Horse?

    private let engine = PredictionEngine()

    private var result: (items: [BettingInstruction], comment: String) {
        engine.predict(
            race: race,
            mode: mode,
            budget: budget,
            selectedTickets: selectedTickets,
            pivotHorse: pivotHorse
        )
    }

    private var instructions: [BettingInstruction] { result.items }
    private var comment: String { result.comment }
    private var totalAmount: Int { instructions.reduce(0) { $0 + $1.totalAmount } }
    private var totalCount: Int  { instructions.reduce(0) { $0 + $1.combinationCount } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                raceInfoCard
                resultBanner
                ForEach(instructions) { BettingInstructionCard(instruction: $0) }
            }
            .padding()
        }
        .navigationTitle("買い目レコメンド結果")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
    }

    // MARK: - Subviews

    private var raceInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(race.venue).font(.system(size: 15, weight: .bold))
                Text(race.raceNumber)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(Color(red: 0.36, green: 0.51, blue: 1.0))
            }
            Text(race.name).font(.system(size: 16, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var resultBanner: some View {
        HStack(spacing: 12) {
            Text("✨").font(.system(size: 32))
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.isEmpty ? "買い目を生成しました！" : comment)
                    .font(.system(size: 15, weight: .bold))
                Text("合計 \(totalAmount)円 ／ \(totalCount)点 ／ \(mode.rawValue)モード")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Copy

    private func copyToClipboard() {
        var lines: [String] = []
        lines.append("【\(race.venue) \(race.raceNumber) \(race.name)】")
        lines.append("合計 \(totalAmount)円 / \(totalCount)点 / \(mode.rawValue)モード")
        lines.append("")
        for inst in instructions {
            lines.append("▼ \(inst.ticketLabel)\(inst.style.label.isEmpty ? "" : "（\(inst.style.label)）")")
            switch inst.style {
            case .single(let horses):
                lines.append("  " + horses.map { "(\($0.number))\($0.name)" }.joined(separator: " "))
            case .nagashi(let axis, let opponents):
                lines.append("  軸: " + axis.map { "(\($0.number))" }.joined(separator: " "))
                lines.append("  相手: " + opponents.map { "(\($0.number))" }.joined(separator: " "))
            case .box(let horses):
                lines.append("  " + horses.map { "(\($0.number))" }.joined(separator: " "))
            case .formation(let first, let second, let third):
                lines.append("  1着: " + first.map { "(\($0.number))" }.joined(separator: " "))
                lines.append("  2着: " + second.map { "(\($0.number))" }.joined(separator: " "))
                lines.append("  3着: " + third.map { "(\($0.number))" }.joined(separator: " "))
            }
            lines.append("  \(inst.combinationCount)点 × \(inst.amountPerCombination)円 = \(inst.totalAmount)円")
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
    }
}

// MARK: - BettingInstructionCard

struct BettingInstructionCard: View {
    let instruction: BettingInstruction

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(instruction.ticketLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.36, green: 0.51, blue: 1.0))
                    .cornerRadius(8)
                if !instruction.style.label.isEmpty {
                    Text(instruction.style.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.36, green: 0.51, blue: 1.0))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.36, green: 0.51, blue: 1.0).opacity(0.12))
                        .cornerRadius(8)
                }
                Spacer()
            }

            styleView

            Divider()

            HStack(spacing: 6) {
                Text("\(instruction.combinationCount)点")
                    .font(.system(size: 15, weight: .bold))
                Text("×").font(.system(size: 13)).foregroundColor(.secondary)
                Text("\(instruction.amountPerCombination)円")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text("= \(instruction.totalAmount)円")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Color(red: 0.36, green: 0.51, blue: 1.0))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private var styleView: some View {
        switch instruction.style {
        case .single(let horses):
            HStack(spacing: 8) {
                ForEach(horses) { h in
                    HorseNumberBadge(number: h.number, name: h.name, role: .normal)
                }
            }

        case .nagashi(let axis, let opponents):
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    RoleLabel(text: "軸", color: .orange)
                    ForEach(axis) { h in HorseNumberBadge(number: h.number, name: nil, role: .axis) }
                }
                HStack(spacing: 8) {
                    RoleLabel(text: "相手", color: Color(red: 0.36, green: 0.51, blue: 1.0))
                    FlexibleHorseRow(horses: opponents, role: .opponent)
                }
            }

        case .box(let horses):
            VStack(alignment: .leading, spacing: 8) {
                Text("選択馬").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                FlexibleHorseRow(horses: horses, role: .normal)
            }

        case .formation(let first, let second, let third):
            VStack(alignment: .leading, spacing: 10) {
                FormationRow(label: "1着", horses: first,  color: Color(red: 0.85, green: 0.15, blue: 0.15))
                FormationRow(label: "2着", horses: second, color: Color(red: 0.36, green: 0.51, blue: 1.0))
                if !third.isEmpty {
                    FormationRow(label: "3着", horses: third, color: Color(red: 0.48, green: 0.22, blue: 0.80))
                }
            }
        }
    }
}

// MARK: - Horse Badge

enum HorseRole { case axis, opponent, normal }

struct HorseNumberBadge: View {
    let number: Int
    let name: String?
    let role: HorseRole

    private var bgColor: Color {
        switch role {
        case .axis:     return .orange
        case .opponent: return Color(red: 0.36, green: 0.51, blue: 1.0)
        case .normal:   return Color(red: 0.36, green: 0.51, blue: 1.0)
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(bgColor)
                Text("\(number)").font(.system(size: 15, weight: .black)).foregroundColor(.white)
            }
            .frame(width: 36, height: 36)
            if let name = name {
                Text(name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 44)
            }
        }
    }
}

// MARK: - Supporting Views

struct RoleLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }
}

struct FlexibleHorseRow: View {
    let horses: [Horse]
    let role: HorseRole

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: min(horses.count, 8)),
            spacing: 6
        ) {
            ForEach(horses) { h in HorseNumberBadge(number: h.number, name: nil, role: role) }
        }
    }
}

struct FormationRow: View {
    let label: String
    let horses: [Horse]
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(6)
            HStack(spacing: 6) {
                ForEach(horses) { h in
                    ZStack {
                        Circle().fill(color.opacity(0.15))
                        Text("\(h.number)")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(color)
                    }
                    .frame(width: 34, height: 34)
                }
            }
        }
    }
}
