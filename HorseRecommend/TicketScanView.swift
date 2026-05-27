import SwiftUI
import PhotosUI
import SwiftData

struct TicketScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedItem: PhotosPickerItem?
    @State private var phase: Phase = .idle
    @State private var parsed: ParsedState?
    @State private var errorMessage: String?
    @State private var showEditView = false
    @State private var editDraft: TicketDraft = TicketDraft()

    private let network = NetworkRaceRepository()

    enum Phase { case idle, loading, preview, done }

    struct ParsedState {
        var result: NetworkRaceRepository.TicketParseResult
        var raceId: String
        var draft: TicketDraft? = nil

        var effectiveDate: String       { draft?.raceDateString ?? result.raceDate }
        var effectiveVenue: String      { draft?.venue ?? result.venue }
        var effectiveRaceNumber: String { draft?.raceNumber ?? result.raceNumber }
        var effectiveRaceName: String   { draft?.raceName ?? result.raceName }
        var effectiveBetType: String    { draft?.betType ?? TicketDraft.normalizeBetType(result.betType) }
        var effectiveBetPattern: String { draft?.betPattern ?? result.betPattern }
        var effectiveIsMulti: Bool      { draft?.isMulti ?? result.isMulti ?? false }
        var effectiveBets: [NetworkRaceRepository.ParsedBet] { draft?.generatedBets ?? result.bets }
        var effectiveTotalAmount: Int   { draft?.totalAmount ?? result.totalAmount }
        var effectivePerAmount: Int     { draft?.perAmount ?? result.bets.first?.amount ?? 100 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SplatTheme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    titleBar
                    switch phase {
                    case .idle:    idleView
                    case .loading: loadingView
                    case .preview: if let s = parsed { previewView(s) }
                    case .done:    doneView
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showEditView) {
                TicketEditView(draft: $editDraft) {
                    parsed?.draft = editDraft
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await process(item: item) }
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        ZStack {
            Text("馬券スキャン")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 36, height: 36)
                        .background(SplatTheme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(ScalePressStyle())
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(SplatTheme.cyan.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(SplatTheme.cyan)
                }
                Text("馬券をAI読み取り")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Text("馬券の写真を選択すると\nAIが自動で買い目を認識します")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                    Text("写真を選択")
                        .font(.system(size: 16, weight: .black))
                }
                .foregroundColor(SplatTheme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(SplatTheme.cyan)
                .cornerRadius(16)
                .shadow(color: SplatTheme.cyan.opacity(0.4), radius: 12, y: 4)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().tint(SplatTheme.cyan).scaleEffect(1.5)
            Text("AI解析中...")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            Text("買い目を認識しています")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
        }
    }

    // MARK: - Preview

    private func previewView(_ state: ParsedState) -> some View {
        let bets = state.effectiveBets

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.35))
                    Text("AI読み取りのため誤りがある場合があります")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Button {
                        editDraft = TicketDraft(from: state.result, currentBets: state.effectiveBets)
                        if let d = state.draft { editDraft = d }
                        showEditView = true
                    } label: {
                        Text("修正")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(SplatTheme.cyan)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(SplatTheme.cyan.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(SplatTheme.cyan.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(12)
                .background(.white.opacity(0.04))
                .cornerRadius(12)

                infoCard {
                    VStack(spacing: 10) {
                        row(label: "日程", value: formattedDate(state.effectiveDate))
                        row(label: "開催", value: "\(state.effectiveVenue) \(state.effectiveRaceNumber)")
                        if !state.effectiveRaceName.isEmpty {
                            row(label: "レース名", value: state.effectiveRaceName)
                        }
                        row(label: "券種", value: state.effectiveBetType)
                        row(label: "方式", value: state.effectiveBetPattern)
                    }
                }

                infoCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("買い目")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(1)
                            if state.effectiveIsMulti && multiCapableBetTypes.contains(state.effectiveBetType) {
                                Text("マルチ")
                                    .font(.system(size: 11, weight: .black))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(SplatTheme.magenta.opacity(0.25))
                                    .foregroundStyle(SplatTheme.magenta)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        Divider().background(.white.opacity(0.08))
                        BetPatternView(
                            betPattern: state.effectiveBetPattern,
                            betType: state.effectiveBetType,
                            isMulti: state.effectiveIsMulti,
                            bets: bets,
                            perAmount: state.effectivePerAmount
                        )
                        Divider().background(.white.opacity(0.08))
                        HStack {
                            Text("合計")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("¥\(state.effectiveTotalAmount)")
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(SplatTheme.yellow)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        phase = .idle; parsed = nil; errorMessage = nil; selectedItem = nil
                    } label: {
                        Text("やり直す")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SplatTheme.card)
                            .cornerRadius(14)
                    }
                    Button { save(state) } label: {
                        Text("保存する")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(SplatTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SplatTheme.cyan)
                            .cornerRadius(14)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    // MARK: - Done

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(SplatTheme.cyan)
            Text("保存しました！")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
            Text("レース結果確定後に自動で\n払戻額を取得します")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    phase = .idle; parsed = nil; selectedItem = nil; errorMessage = nil
                } label: {
                    Text("続けてスキャン")
                        .font(.system(size: 15, weight: .black)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(SplatTheme.card).cornerRadius(14)
                }
                Button { dismiss() } label: {
                    Text("閉じる")
                        .font(.system(size: 15, weight: .black)).foregroundColor(SplatTheme.bg)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(SplatTheme.cyan).cornerRadius(14)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SplatTheme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private func formattedDate(_ dateStr: String) -> String {
        guard dateStr.count == 8 else { return dateStr }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd"
        guard let date = fmt.date(from: dateStr) else { return dateStr }
        let out = DateFormatter(); out.dateFormat = "M/d(E)"; out.locale = Locale(identifier: "ja_JP")
        return out.string(from: date)
    }

    // MARK: - Logic

    private func process(item: PhotosPickerItem) async {
        phase = .loading
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw TicketParserError.invalidImage
            }
            let result = try await network.parseTicketVision(imageData: data)
            await MainActor.run {
                parsed = ParsedState(result: result, raceId: result.raceId ?? "")
                phase = .preview
            }
        } catch {
            await MainActor.run {
                errorMessage = "認識に失敗しました。鮮明な写真で再試行してください。"
                phase = .idle
                selectedItem = nil
            }
        }
    }

    private func save(_ state: ParsedState) {
        let betEntries = state.effectiveBets.map {
            BetEntry(horses: $0.horses.filter { $0 >= 1 && $0 <= 18 }, amount: $0.amount)
        }
        let record = TicketRecord(
            raceDate: state.effectiveDate,
            venue: state.effectiveVenue,
            raceNumber: state.effectiveRaceNumber,
            raceName: state.effectiveRaceName,
            betType: state.effectiveBetType,
            betPattern: state.effectiveBetPattern,
            isMulti: state.effectiveIsMulti,
            bets: betEntries,
            totalAmount: state.effectiveTotalAmount
        )
        record.raceId = state.raceId
        modelContext.insert(record)
        try? modelContext.save()
        withAnimation { phase = .done }

        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd"
        let today = fmt.string(from: Date())
        guard record.raceDate <= today && !record.raceId.isEmpty else { return }
        Task {
            if let full = await network.fetchRaceResultFull(raceId: record.raceId),
               !full.results.isEmpty {
                record.resolvePayout(payoutsMap: full.payouts)
                try? modelContext.save()
            }
        }
    }
}
