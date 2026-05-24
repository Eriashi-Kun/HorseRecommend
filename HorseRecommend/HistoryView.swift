import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \PredictionRecord.savedAt, order: .reverse) private var records: [PredictionRecord]
    @Environment(\.dismiss) private var dismiss

    private let network = NetworkRaceRepository()

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.06, blue: 0.14).ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 36, height: 36)
                            .background(SplatTheme.card)
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScalePressStyle())
                    Spacer()
                    Text("予想履歴")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if records.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(records) { record in
                                HistoryCard(record: record, network: network)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🏇")
                .font(.system(size: 56))
            Text("まだ予想履歴がありません")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - HistoryCard

struct HistoryCard: View {
    let record: PredictionRecord
    let network: NetworkRaceRepository
    @State private var picks: [PickData] = []
    @State private var isFetchingResult = false
    @Environment(\.modelContext) private var modelContext

    private var isPastRace: Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        let today = fmt.string(from: Date())
        return record.day < today
    }

    private var dateDisplay: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        guard let date = fmt.date(from: record.day) else { return record.day }
        let out = DateFormatter()
        out.dateFormat = "M/d"
        out.locale = Locale(identifier: "ja_JP")
        return out.string(from: date)
    }

    private var typeColor: Color {
        record.predictionTypeEnum?.color ?? .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image("HorseIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .colorMultiply(typeColor)
                    .brightness(0.15)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.raceName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(dateDisplay)  \(record.venue)  \(record.raceNumber)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text(record.predictionType)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(typeColor.opacity(0.25))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())
            }

            Divider().background(.white.opacity(0.1))

            // Picks
            VStack(spacing: 6) {
                ForEach(picks.indices, id: \.self) { i in
                    PickRow(pick: picks[i])
                }
            }

            if isFetchingResult {
                HStack {
                    Spacer()
                    ProgressView().tint(.white.opacity(0.4)).scaleEffect(0.7)
                    Text("結果取得中...")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            picks = record.picks
            if isPastRace && !record.raceId.isEmpty && picks.allSatisfy({ $0.finishPosition == nil }) {
                Task { await fetchResult() }
            }
        }
    }

    private func fetchResult() async {
        isFetchingResult = true
        defer { isFetchingResult = false }
        let resultMap = await network.fetchRaceResult(raceId: record.raceId)
        guard !resultMap.isEmpty else { return }
        var updated = record.picks
        for i in updated.indices {
            updated[i].finishPosition = resultMap[updated[i].horseNumber]
        }
        record.picks = updated
        try? modelContext.save()
        picks = updated
    }
}

// MARK: - PickRow

struct PickRow: View {
    let pick: PickData

    private var finishBadge: (label: String, color: Color)? {
        guard let pos = pick.finishPosition else { return nil }
        switch pos {
        case 1: return ("1着", Color(red: 1.00, green: 0.84, blue: 0.00))
        case 2: return ("2着", Color(red: 0.75, green: 0.75, blue: 0.75))
        case 3: return ("3着", Color(red: 0.80, green: 0.50, blue: 0.20))
        default: return ("\(pos)着", Color.white.opacity(0.3))
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(pick.horseNumber)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.1))
                .clipShape(Circle())
                .foregroundStyle(.white)

            Text(pick.horseName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text(String(format: "%.1f倍", pick.odds))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))

            if let badge = finishBadge {
                Text(badge.label)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badge.color.opacity(pick.finishPosition! <= 3 ? 0.25 : 0.15))
                    .foregroundStyle(badge.color)
                    .clipShape(Capsule())
            } else if pick.finishPosition == nil {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }
}
