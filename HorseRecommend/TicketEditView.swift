import SwiftUI

// MARK: - TicketDraft

struct TicketDraft {
    var raceDate: Date
    var venue: String
    var raceNumber: String
    var raceName: String
    var betType: String
    var betPattern: String
    var isMulti: Bool
    var perAmount: Int
    var totalAmount: Int

    // ながし用
    var pivot: Int
    var partners: Set<Int>

    // ボックス / 通常(単勝・複勝) 用
    var allHorses: Set<Int>

    // フォーメーション用（[row0, row1] or [row0, row1, row2]）
    var formationRows: [Set<Int>]

    // 通常(複数馬番) 用：AIが正しく読んだ元の買い目を保持
    var originalBets: [NetworkRaceRepository.ParsedBet]

    static let venues    = ["東京", "中山", "阪神", "京都", "中京", "新潟", "福島", "小倉", "函館", "札幌"]
    static let betTypes  = ["単勝", "複勝", "枠連", "馬連", "馬単", "ワイド", "三連複", "三連単"]
    static let betPatterns = ["通常", "ながし", "フォーメーション", "ボックス"]
    static let raceNumbers = (1...12).map { "\($0)R" }

    var isNagashi: Bool     { betPattern == "ながし" }
    var isBox: Bool         { betPattern == "ボックス" }
    var isFormation: Bool   { betPattern == "フォーメーション" }
    var isThreeHorse: Bool  { ["三連複", "三連単"].contains(betType) }
    var isSingleHorse: Bool { ["単勝", "複勝"].contains(betType) }

    // MARK: Bet generation

    var generatedBets: [NetworkRaceRepository.ParsedBet] {
        switch betPattern {
        case "ながし":       return nagashiBets
        case "ボックス":     return boxBets
        case "フォーメーション": return formationBets
        default:            return normalBets
        }
    }

    private var nagashiBets: [NetworkRaceRepository.ParsedBet] {
        let pp = partners.sorted()
        var bets: [NetworkRaceRepository.ParsedBet] = []
        if isThreeHorse {
            for i in 0..<pp.count {
                for j in (i + 1)..<pp.count {
                    bets.append(.init(horses: [pivot, pp[i], pp[j]], amount: perAmount))
                }
            }
        } else {
            for p in pp {
                bets.append(.init(horses: [pivot, p], amount: perAmount))
                if isMulti && multiCapableBetTypes.contains(betType) {
                    bets.append(.init(horses: [p, pivot], amount: perAmount))
                }
            }
        }
        return bets
    }

    private var boxBets: [NetworkRaceRepository.ParsedBet] {
        let hs = allHorses.sorted()
        var bets: [NetworkRaceRepository.ParsedBet] = []
        switch betType {
        case "馬連", "ワイド":
            for i in 0..<hs.count { for j in (i+1)..<hs.count {
                bets.append(.init(horses: [hs[i], hs[j]], amount: perAmount))
            }}
        case "馬単":
            for a in hs { for b in hs where b != a {
                bets.append(.init(horses: [a, b], amount: perAmount))
            }}
        case "三連複":
            for i in 0..<hs.count { for j in (i+1)..<hs.count { for k in (j+1)..<hs.count {
                bets.append(.init(horses: [hs[i], hs[j], hs[k]], amount: perAmount))
            }}}
        case "三連単":
            for a in hs { for b in hs where b != a { for c in hs where c != a && c != b {
                bets.append(.init(horses: [a, b, c], amount: perAmount))
            }}}
        default:
            bets = hs.map { .init(horses: [$0], amount: perAmount) }
        }
        return bets
    }

    private var formationBets: [NetworkRaceRepository.ParsedBet] {
        guard formationRows.count >= 2 else { return [] }
        let r0 = formationRows[0].sorted()
        let r1 = formationRows[1].sorted()
        var bets: [NetworkRaceRepository.ParsedBet] = []

        if isThreeHorse && formationRows.count >= 3 {
            let r2 = formationRows[2].sorted()
            if betType == "三連複" {
                // 3行から一意な3頭組み合わせを生成
                var seen = Set<String>()
                for a in r0 { for b in r1 where b != a { for c in r2 where c != a && c != b {
                    let key = [a, b, c].sorted().map(String.init).joined(separator: "-")
                    if seen.insert(key).inserted {
                        bets.append(.init(horses: [a, b, c].sorted(), amount: perAmount))
                    }
                }}}
            } else { // 三連単
                for a in r0 { for b in r1 where b != a { for c in r2 where c != a && c != b {
                    bets.append(.init(horses: [a, b, c], amount: perAmount))
                }}}
            }
        } else {
            // 2行（馬連・馬単・ワイド・枠連）
            for a in r0 { for b in r1 where b != a {
                if betType == "馬連" || betType == "ワイド" || betType == "枠連" {
                    let key = [a, b].sorted().map(String.init).joined(separator: "-")
                    // 重複除去
                    bets.append(.init(horses: [a, b], amount: perAmount))
                } else {
                    bets.append(.init(horses: [a, b], amount: perAmount))
                }
            }}
            // 馬連/ワイドは重複排除
            if betType == "馬連" || betType == "ワイド" || betType == "枠連" {
                var seen = Set<String>()
                bets = bets.filter {
                    let key = $0.horses.sorted().map(String.init).joined(separator: "-")
                    return seen.insert(key).inserted
                }
            }
        }
        return bets
    }

    private var normalBets: [NetworkRaceRepository.ParsedBet] {
        // 単勝・複勝は allHorses で個別購入
        if isSingleHorse {
            return allHorses.sorted().map { .init(horses: [$0], amount: perAmount) }
        }
        // 手動入力 or AI読み取り済み：originalBets をそのまま使用（金額のみ更新）
        return originalBets.map { .init(horses: $0.horses, amount: perAmount) }
    }

    var calcTotal: Int { generatedBets.count * perAmount }

    var raceDateString: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd"
        return fmt.string(from: raceDate)
    }

    // MARK: Inits

    init() {
        raceDate = Date()
        venue = TicketDraft.venues[0]
        raceNumber = "1R"
        raceName = ""
        betType = "複勝"
        betPattern = "通常"
        isMulti = false
        pivot = 1
        partners = []
        allHorses = []
        formationRows = [[], []]
        originalBets = []
        perAmount = 100
        totalAmount = 0
    }

    init(from result: NetworkRaceRepository.TicketParseResult,
         currentBets: [NetworkRaceRepository.ParsedBet]) {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd"
        raceDate = fmt.date(from: result.raceDate) ?? Date()
        venue = result.venue
        let numStr = result.raceNumber.filter { $0.isNumber }
        raceNumber = numStr.isEmpty ? "1R" : "\(numStr)R"
        raceName = result.raceName
        betType = TicketDraft.normalizeBetType(result.betType)
        betPattern = result.betPattern
        isMulti = result.isMulti ?? false
        totalAmount = result.totalAmount
        originalBets = currentBets
        perAmount = currentBets.first?.amount ?? 100

        // ながし用
        let allSets = currentBets.map { Set($0.horses) }
        let common = allSets.dropFirst().reduce(allSets.first ?? []) { $0.intersection($1) }
        let piv = common.first ?? currentBets.first?.horses.first ?? 1
        pivot = piv
        var ps = Set<Int>(); var ahs = Set<Int>()
        for bet in currentBets {
            for h in bet.horses where h >= 1 && h <= 18 { ahs.insert(h); if h != piv { ps.insert(h) } }
        }
        partners = ps; allHorses = ahs

        // フォーメーション用
        let positions = ["三連複", "三連単"].contains(betType) ? 3 : 2
        formationRows = (0..<positions).map { pos in
            Set(currentBets.compactMap { bet in bet.horses.count > pos ? bet.horses[pos] : nil })
        }
    }

    init(from record: TicketRecord) {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd"
        raceDate = fmt.date(from: record.raceDate) ?? Date()
        venue = record.venue
        let numStr = record.raceNumber.filter { $0.isNumber }
        raceNumber = numStr.isEmpty ? "1R" : "\(numStr)R"
        raceName = record.raceName
        betType = record.betType
        betPattern = record.betPattern
        isMulti = record.isMulti
        totalAmount = record.totalAmount

        let bets = record.bets
        originalBets = bets.map { NetworkRaceRepository.ParsedBet(horses: $0.horses, amount: $0.amount) }
        perAmount = bets.first?.amount ?? 100

        let allSets = bets.map { Set($0.horses) }
        let common = allSets.dropFirst().reduce(allSets.first ?? []) { $0.intersection($1) }
        let piv = common.first ?? bets.first?.horses.first ?? 1
        pivot = piv
        var ps = Set<Int>(); var ahs = Set<Int>()
        for bet in bets {
            for h in bet.horses where h >= 1 && h <= 18 { ahs.insert(h); if h != piv { ps.insert(h) } }
        }
        partners = ps; allHorses = ahs

        let positions = ["三連複", "三連単"].contains(betType) ? 3 : 2
        formationRows = (0..<positions).map { pos in
            Set(bets.compactMap { bet in bet.horses.count > pos ? bet.horses[pos] : nil })
        }
    }

    static func normalizeBetType(_ raw: String) -> String {
        let map: [String: String] = [
            "EXACTA": "馬単", "QUINELLA": "馬連", "TRIFECTA": "三連単",
            "TRIO": "三連複", "WIDE": "ワイド", "WIN": "単勝", "PLACE": "複勝",
            "QUINELLA PLACE": "ワイド", "BRACKET QUINELLA": "枠連",
        ]
        return map[raw.uppercased()] ?? raw
    }

    // フォーメーション行数をbetTypeに合わせて調整
    mutating func syncFormationRows() {
        let need = isThreeHorse ? 3 : 2
        while formationRows.count < need { formationRows.append([]) }
        if formationRows.count > need { formationRows = Array(formationRows.prefix(need)) }
    }
}

// MARK: - TicketEditView

struct TicketEditView: View {
    @Binding var draft: TicketDraft
    let onConfirm: () -> Void
    var title: String = "内容を修正"
    var confirmLabel: String = "確定"
    @Environment(\.dismiss) private var dismiss
    @State private var showPivotPicker = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        ZStack {
            SplatTheme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                Divider().background(.white.opacity(0.1))
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        raceInfoSection
                        betTypeSection
                        horsesSection
                        amountSection
                    }
                    .padding(16).padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPivotPicker) {
            HorseNumberPicker(excluded: Array(draft.partners)) { n in
                draft.pivot = n
                draft.partners.remove(n)
                showPivotPicker = false
            }
        }
        .onTapGesture { amountFocused = false }
        .onChange(of: draft.betType) { _, _ in draft.syncFormationRows() }
    }

    private var navBar: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("戻る")
                            .font(.system(size: 16))
                    }
                    .foregroundStyle(SplatTheme.cyan)
                }
                Spacer()
                Button(confirmLabel) { onConfirm(); dismiss() }
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(SplatTheme.cyan)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    // MARK: - Sections

    private var raceInfoSection: some View {
        editSection(title: "レース情報") {
            VStack(spacing: 0) {
                editRow(label: "日程") {
                    DatePicker("", selection: $draft.raceDate, displayedComponents: .date)
                        .datePickerStyle(.compact).labelsHidden().colorScheme(.dark)
                }
                sep
                editRow(label: "場所") {
                    Picker("", selection: $draft.venue) {
                        ForEach(TicketDraft.venues, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).tint(SplatTheme.cyan)
                }
                sep
                editRow(label: "レース") {
                    Picker("", selection: $draft.raceNumber) {
                        ForEach(TicketDraft.raceNumbers, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).tint(SplatTheme.cyan)
                }
                sep
                editRow(label: "レース名") {
                    TextField("任意", text: $draft.raceName)
                        .font(.system(size: 14)).foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var betTypeSection: some View {
        editSection(title: "券種") {
            VStack(spacing: 0) {
                editRow(label: "券種") {
                    Picker("", selection: $draft.betType) {
                        ForEach(TicketDraft.betTypes, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).tint(SplatTheme.cyan)
                }
                sep
                editRow(label: "方式") {
                    Picker("", selection: $draft.betPattern) {
                        ForEach(TicketDraft.betPatterns, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).tint(SplatTheme.cyan)
                }
                if multiCapableBetTypes.contains(draft.betType) {
                    sep
                    editRow(label: "マルチ") {
                        Toggle("", isOn: $draft.isMulti).tint(SplatTheme.cyan)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var horsesSection: some View {
        switch draft.betPattern {
        case "ながし":
            editSection(title: "軸") {
                HStack(spacing: 10) {
                    horseCircle(draft.pivot, color: SplatTheme.yellow)
                    Button { showPivotPicker = true } label: {
                        Text("変更")
                            .font(.system(size: 12, weight: .black))
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.white.opacity(0.1))
                            .foregroundStyle(.white.opacity(0.7))
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
            editSection(title: "相手（タップで選択 / 解除）") {
                horseMultiGrid(selected: $draft.partners, excluded: [draft.pivot])
            }

        case "ボックス":
            editSection(title: "馬番（タップで選択 / 解除）") {
                horseMultiGrid(selected: $draft.allHorses, excluded: [])
            }

        case "フォーメーション":
            formationSection

        default: // 通常
            if draft.isSingleHorse {
                editSection(title: "馬番（タップで選択 / 解除）") {
                    horseMultiGrid(selected: $draft.allHorses, excluded: [])
                }
            } else if !draft.originalBets.isEmpty {
                // AI読み取り済み or 手動追加済み：買い目リスト＋追加グリッド
                normalManualSection
            } else {
                // 手動入力（まだ買い目なし）
                normalManualSection
            }
        }
    }

    @ViewBuilder
    private var normalManualSection: some View {
        let required = draft.isThreeHorse ? 3 : 2
        let isAI = draft.originalBets.contains { $0.horses.count >= 2 } && draft.allHorses.isEmpty

        if isAI {
            // AIスキャン済み：読み取り結果を表示（金額のみ変更可）
            editSection(title: "買い目（AI読み取り結果・金額のみ変更可）") {
                VStack(spacing: 6) {
                    ForEach(draft.originalBets.indices, id: \.self) { i in
                        HStack {
                            Text(draft.originalBets[i].horses.map(String.init).joined(separator: " - "))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                }
            }
        } else {
            // 手動入力：1組ずつ追加
            if !draft.originalBets.isEmpty {
                editSection(title: "入力済み買い目") {
                    VStack(spacing: 8) {
                        ForEach(draft.originalBets.indices, id: \.self) { i in
                            HStack {
                                Text(draft.originalBets[i].horses.map(String.init).joined(separator: " - "))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button {
                                    draft.originalBets.remove(at: i)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
            editSection(title: "\(required)頭選ぶと自動追加") {
                horseMultiGrid(selected: $draft.allHorses, excluded: [])
            }
            .onChange(of: draft.allHorses) { _, horses in
                if horses.count == required {
                    draft.originalBets.append(
                        .init(horses: horses.sorted(), amount: draft.perAmount)
                    )
                    draft.allHorses = []
                }
            }
        }
    }

    @ViewBuilder
    private var formationSection: some View {
        let rowLabels = draft.isThreeHorse
            ? (draft.betType == "三連単" ? ["1着候補", "2着候補", "3着候補"]
                                         : ["1頭目候補", "2頭目候補", "3頭目候補"])
            : (draft.betType == "馬単"   ? ["1着候補", "2着候補"]
                                         : ["1頭目候補", "2頭目候補"])

        ForEach(draft.formationRows.indices, id: \.self) { row in
            editSection(title: "\(rowLabels[safe: row] ?? "行\(row+1)")（タップで選択 / 解除）") {
                horseMultiGrid(
                    selected: Binding(
                        get: { row < draft.formationRows.count ? draft.formationRows[row] : [] },
                        set: { if row < draft.formationRows.count { draft.formationRows[row] = $0 } }
                    ),
                    excluded: []
                )
            }
        }
    }

    private var amountSection: some View {
        editSection(title: "金額") {
            VStack(spacing: 0) {
                editRow(label: "1点") {
                    HStack(spacing: 4) {
                        TextField("100", value: $draft.perAmount, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .focused($amountFocused)
                        Text("円").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                    }
                }
                sep
                HStack {
                    Text("計算合計").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    let calc = draft.calcTotal
                    let ok = calc == draft.totalAmount
                    HStack(spacing: 5) {
                        Text("¥\(calc)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(ok ? SplatTheme.cyan : SplatTheme.yellow)
                        if !ok {
                            Text("(券面¥\(draft.totalAmount))")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                            Image(systemName: "exclamationmark.circle.fill").foregroundColor(SplatTheme.yellow)
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(SplatTheme.cyan)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - Helpers

    private func editSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SplatTheme.card)
        .cornerRadius(14)
    }

    private func editRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 60, alignment: .leading)
            Spacer()
            content()
        }
        .padding(.vertical, 10)
    }

    private var sep: some View { Divider().background(.white.opacity(0.06)) }

    private func horseMultiGrid(selected: Binding<Set<Int>>, excluded: [Int]) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 10) {
            ForEach(1...18, id: \.self) { n in
                let isSel = selected.wrappedValue.contains(n)
                let isEx = excluded.contains(n)
                Button {
                    guard !isEx else { return }
                    if isSel { selected.wrappedValue.remove(n) } else { selected.wrappedValue.insert(n) }
                } label: {
                    Text("\(n)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .frame(width: 44, height: 44)
                        .background(isEx ? Color.white.opacity(0.04) : isSel ? SplatTheme.cyan.opacity(0.25) : Color.white.opacity(0.07))
                        .foregroundStyle(isEx ? .white.opacity(0.15) : isSel ? SplatTheme.cyan : .white.opacity(0.55))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isSel ? SplatTheme.cyan.opacity(0.6) : .clear, lineWidth: 1.5))
                }
                .disabled(isEx)
            }
        }
    }

    private func horseCircle(_ num: Int, color: Color) -> some View {
        Text("\(num)")
            .font(.system(size: 14, weight: .black, design: .monospaced))
            .frame(width: 38, height: 38)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 1.5))
    }
}

// MARK: - HorseNumberPicker (軸専用・単選択)

struct HorseNumberPicker: View {
    let excluded: [Int]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            SplatTheme.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("軸馬番を選択")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 12) {
                    ForEach(1...18, id: \.self) { n in
                        let isEx = excluded.contains(n)
                        Button {
                            guard !isEx else { return }
                            onSelect(n)
                        } label: {
                            Text("\(n)")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .frame(width: 46, height: 46)
                                .background(isEx ? Color.white.opacity(0.05) : SplatTheme.yellow.opacity(0.2))
                                .foregroundStyle(isEx ? .white.opacity(0.2) : SplatTheme.yellow)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(isEx ? .clear : SplatTheme.yellow.opacity(0.4), lineWidth: 1))
                        }
                        .disabled(isEx)
                    }
                }
                .padding(.horizontal, 20)
                Button("キャンセル") { dismiss() }
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.height(340)])
    }
}

