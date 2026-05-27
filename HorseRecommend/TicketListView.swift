import SwiftUI
import SwiftData

struct TicketListView: View {
    @Query(sort: \TicketRecord.savedAt, order: .reverse) private var tickets: [TicketRecord]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showScan = false
    @State private var resolvingIds: Set<UUID> = []
    @State private var showEditView = false
    @State private var editDraft: TicketDraft = TicketDraft()
    @State private var editingTicket: TicketRecord? = nil
    @State private var showManualInput = false
    @State private var newDraft: TicketDraft = TicketDraft()
    @State private var showHitCelebration = false
    @State private var celebrationPayout = 0
    @State private var celebrationXP = 0

    private let network = NetworkRaceRepository()

    private var totalSpent: Int  { tickets.reduce(0) { $0 + $1.totalAmount } }
    private var totalReturn: Int { tickets.reduce(0) { $0 + $1.payout } }
    private var netPL: Int       { totalReturn - totalSpent }

    var body: some View {
        ZStack {
                SplatTheme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    titleBar

                    if tickets.isEmpty {
                        emptyState
                    } else {
                        plSummary
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(tickets) { ticket in
                                    TicketCard(
                                        ticket: ticket,
                                        isResolving: resolvingIds.contains(ticket.id)
                                    ) {
                                        Task { await resolve(ticket) }
                                    }
                                    .contextMenu {
                                        Button {
                                            editDraft = TicketDraft(from: ticket)
                                            editingTicket = ticket
                                            showEditView = true
                                        } label: {
                                            Label("修正", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            modelContext.delete(ticket)
                                            try? modelContext.save()
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            editDraft = TicketDraft(from: ticket)
                                            editingTicket = ticket
                                            showEditView = true
                                        } label: {
                                            Label("修正", systemImage: "pencil")
                                        }
                                        .tint(SplatTheme.cyan)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            modelContext.delete(ticket)
                                            try? modelContext.save()
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 40)
                        }
                    }
                }

                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            newDraft = TicketDraft()
                            showManualInput = true
                        } label: {
                            Label("手動入力", systemImage: "square.and.pencil")
                                .font(.system(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(SplatTheme.surface)
                                .cornerRadius(30)
                                .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(ScalePressStyle())

                        Button { showScan = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("AIスキャン")
                                    .font(.system(size: 15, weight: .black))
                            }
                            .foregroundColor(SplatTheme.bg)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(SplatTheme.cyan)
                            .cornerRadius(30)
                            .shadow(color: SplatTheme.cyan.opacity(0.5), radius: 12, y: 4)
                        }
                        .buttonStyle(ScalePressStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showEditView) {
            TicketEditView(draft: $editDraft) {
                guard let ticket = editingTicket else { return }
                applyDraft(editDraft, to: ticket)
            }
        }
        .navigationDestination(isPresented: $showManualInput) {
            TicketEditView(draft: $newDraft, onConfirm: { saveNewTicket(newDraft) }, title: "馬券を入力", confirmLabel: "保存")
        }
        .fullScreenCover(isPresented: $showScan) { TicketScanView() }
        .preferredColorScheme(.dark)
        .task {
            await resolveAllPending()
        }
        .overlay {
            if showHitCelebration {
                HitCelebrationOverlay(
                    payout: celebrationPayout,
                    xpGained: celebrationXP
                ) {
                    withAnimation { showHitCelebration = false }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .background(SplatTheme.card)
                    .clipShape(Circle())
            }
            .buttonStyle(ScalePressStyle())
            Spacer()
            Text("馬券管理")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - P&L Summary

    private var plSummary: some View {
        HStack(spacing: 0) {
            plChip(label: "投資額", value: "¥\(totalSpent)", color: .white)
            Divider().frame(height: 32).background(.white.opacity(0.1))
            plChip(label: "回収額", value: "¥\(totalReturn)", color: SplatTheme.cyan)
            Divider().frame(height: 32).background(.white.opacity(0.1))
            plChip(
                label: "損益",
                value: (netPL >= 0 ? "+" : "") + "¥\(netPL)",
                color: netPL >= 0 ? SplatTheme.yellow : .red.opacity(0.8)
            )
        }
        .padding(.vertical, 12)
        .background(SplatTheme.surface)
    }

    private func plChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "ticket")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.2))
            Text("馬券がまだありません")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
            Text("下のボタンから馬券を\nスキャンして追加できます")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Logic

    private func resolveAllPending() async {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd"
        let today = fmt.string(from: Date())
        let pending = tickets.filter { !$0.isResolved && $0.raceDate <= today }
        var totalPayout = 0
        var totalXP = 0
        for ticket in pending {
            let wasHit = ticket.isHit
            await resolveCore(ticket)
            if !wasHit && ticket.isHit {
                totalPayout += ticket.payout
                totalXP += PlayerStats.xpForTicketHit(betType: ticket.betType)
            }
        }
        if totalPayout > 0 {
            celebrationPayout = totalPayout
            celebrationXP = totalXP
            withAnimation { showHitCelebration = true }
        }
    }

    private func applyDraft(_ draft: TicketDraft, to ticket: TicketRecord) {
        ticket.raceDate = draft.raceDateString
        ticket.venue = draft.venue
        ticket.raceNumber = draft.raceNumber
        ticket.raceName = draft.raceName
        ticket.betType = draft.betType
        ticket.betPattern = draft.betPattern
        ticket.isMulti = draft.isMulti
        ticket.totalAmount = draft.totalAmount
        ticket.bets = draft.generatedBets.map { BetEntry(horses: $0.horses, amount: $0.amount) }
        ticket.isResolved = false
        ticket.payout = 0
        try? modelContext.save()
    }

    private func saveNewTicket(_ draft: TicketDraft) {
        let betEntries = draft.generatedBets.map {
            BetEntry(horses: $0.horses.filter { $0 >= 1 && $0 <= 18 }, amount: $0.amount)
        }
        let record = TicketRecord(
            raceDate: draft.raceDateString,
            venue: draft.venue,
            raceNumber: draft.raceNumber,
            raceName: draft.raceName,
            betType: draft.betType,
            betPattern: draft.betPattern,
            isMulti: draft.isMulti,
            bets: betEntries,
            totalAmount: draft.calcTotal
        )
        modelContext.insert(record)
        try? modelContext.save()

        // 過去レースなら結果取得を試みる
        Task {
            if let found = await network.findRaceId(
                date: record.raceDate,
                venue: record.venue,
                raceNumber: record.raceNumber
            ) {
                record.raceId = found
                try? modelContext.save()
                await resolve(record)
            }
        }
    }

    private func resolve(_ ticket: TicketRecord) async {
        let wasHit = ticket.isHit
        await resolveCore(ticket)
        if !wasHit && ticket.isHit {
            celebrationPayout = ticket.payout
            celebrationXP = PlayerStats.xpForTicketHit(betType: ticket.betType)
            withAnimation { showHitCelebration = true }
        }
    }

    private func resolveCore(_ ticket: TicketRecord) async {
        guard !resolvingIds.contains(ticket.id) else { return }
        resolvingIds.insert(ticket.id)
        defer { resolvingIds.remove(ticket.id) }

        if ticket.raceId.isEmpty {
            if let found = await network.findRaceId(
                date: ticket.raceDate,
                venue: ticket.venue,
                raceNumber: ticket.raceNumber
            ) {
                ticket.raceId = found
                try? modelContext.save()
            }
        }

        guard !ticket.raceId.isEmpty else { return }
        guard let full = await network.fetchRaceResultFull(raceId: ticket.raceId),
              !full.results.isEmpty else { return }
        ticket.resolvePayout(payoutsMap: full.payouts)
        try? modelContext.save()
    }
}

// MARK: - TicketCard

struct TicketCard: View {
    let ticket: TicketRecord
    let isResolving: Bool
    let onRefresh: () -> Void

    private var statusColor: Color {
        if !ticket.isResolved { return .white.opacity(0.3) }
        return ticket.isHit ? SplatTheme.yellow : .red.opacity(0.7)
    }

    private var dateDisplay: String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMdd"
        guard let d = fmt.date(from: ticket.raceDate) else { return ticket.raceDate }
        let out = DateFormatter(); out.dateFormat = "M/d"; out.locale = Locale(identifier: "ja_JP")
        return out.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(ticket.betType)
                            .font(.system(size: 12, weight: .black))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(SplatTheme.cyan.opacity(0.2))
                            .foregroundStyle(SplatTheme.cyan)
                            .clipShape(Capsule())
                        Text(ticket.betPattern)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                        if ticket.isMulti && multiCapableBetTypes.contains(ticket.betType) {
                            Text("マルチ")
                                .font(.system(size: 11, weight: .black))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(SplatTheme.magenta.opacity(0.25))
                                .foregroundStyle(SplatTheme.magenta)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(dateDisplay)  \(ticket.venue)  \(ticket.raceNumber)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                    if !ticket.raceName.isEmpty {
                        Text(ticket.raceName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                Spacer()
                statusBadge
            }

            Divider().background(.white.opacity(0.08))

            TicketBetPatternView(ticket: ticket)

            Divider().background(.white.opacity(0.08))

            HStack {
                Text("投資 ¥\(ticket.totalAmount)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                if ticket.isResolved {
                    let net = ticket.netAmount
                    Text((net >= 0 ? "+" : "") + "¥\(net)")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(net >= 0 ? SplatTheme.yellow : .red.opacity(0.8))
                } else if isResolving {
                    HStack(spacing: 6) {
                        ProgressView().tint(.white.opacity(0.4)).scaleEffect(0.7)
                        Text("結果取得中").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    }
                } else {
                    Button(action: onRefresh) {
                        Label("結果を取得", systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(SplatTheme.cyan)
                    }
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(statusColor.opacity(0.3), lineWidth: 1))
    }

    private var statusBadge: some View {
        Group {
            if ticket.isResolved {
                Text(ticket.isHit ? "的中" : "ハズレ")
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(statusColor.opacity(0.18))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            } else {
                Text("結果待ち")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}
