import SwiftUI

// MARK: - Enums

enum RaceGrade: String {
    case g1 = "G1"
    case g2 = "G2"
    case g3 = "G3"
    case listed = "L"
    case open = "OP"
    case special = ""

    var displayText: String { rawValue.isEmpty ? "OP" : rawValue }

    var color: Color {
        switch self {
        case .g1:              return Color(red: 0.85, green: 0.12, blue: 0.12)
        case .g2:              return Color(red: 0.52, green: 0.18, blue: 0.78)
        case .g3:              return Color(red: 0.14, green: 0.48, blue: 0.84)
        case .listed:          return Color(red: 0.12, green: 0.60, blue: 0.32)
        case .open, .special:  return Color.gray
        }
    }
}

enum RaceDay: String, CaseIterable, Equatable {
    case saturday
    case sunday

    var label: String { self == .saturday ? "土曜日" : "日曜日" }
}

// MARK: - Models

enum RunningStyle: String {
    case front   = "逃"
    case stalker = "先"
    case midpack = "差"
    case closer  = "追"

    var color: Color {
        switch self {
        case .front:   return Color(red: 0.85, green: 0.15, blue: 0.15)
        case .stalker: return Color(red: 0.95, green: 0.55, blue: 0.10)
        case .midpack: return Color(red: 0.20, green: 0.45, blue: 0.90)
        case .closer:  return Color(red: 0.55, green: 0.20, blue: 0.80)
        }
    }
}

struct Horse: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let odds: Double
    let runningStyle: RunningStyle
}

struct Race: Identifiable {
    let id = UUID()
    let day: RaceDay
    let venue: String
    let raceNumber: String
    let name: String
    let grade: RaceGrade
    let distance: String
    let condition: String
    let time: String
    let horses: [Horse]
}

// MARK: - RaceSelectionView

struct RaceSelectionView: View {
    var onSelect: (Race) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDay: RaceDay = .saturday
    @State private var selectedVenue: String = ""

    let races: [Race] = sampleRaces

    private func venues(for day: RaceDay) -> [String] {
        let order = ["札幌","函館","福島","新潟","中山","東京","中京","京都","阪神","小倉"]
        let present = Set(races.filter { $0.day == day }.map { $0.venue })
        return order.filter { present.contains($0) }
    }

    private var currentVenues: [String] { venues(for: selectedDay) }

    private var displayedRaces: [Race] {
        races
            .filter { $0.day == selectedDay && $0.venue == selectedVenue }
            .sorted { $0.raceNumber < $1.raceNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            daySelector
            venueSelector
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(displayedRaces) { race in
                        Button {
                            onSelect(race)
                            dismiss()
                        } label: {
                            RaceCard(race: race)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        }
        .navigationTitle("レース選択")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .onAppear {
            if selectedVenue.isEmpty {
                selectedVenue = currentVenues.first ?? ""
            }
        }
        .onChange(of: selectedDay) { newDay in
            selectedVenue = venues(for: newDay).first ?? ""
        }
    }

    // MARK: - Day Selector

    private var daySelector: some View {
        HStack(spacing: 0) {
            ForEach(RaceDay.allCases, id: \.self) { day in
                Button(action: { selectedDay = day }) {
                    VStack(spacing: 2) {
                        Text(day.label)
                            .font(.system(size: 14, weight: .bold))
                        Text(dateString(for: day))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(selectedDay == day
                        ? Color(red: 0.36, green: 0.51, blue: 1.0)
                        : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle()
                            .fill(selectedDay == day
                                ? Color(red: 0.36, green: 0.51, blue: 1.0)
                                : Color.clear)
                            .frame(height: 2),
                        alignment: .bottom
                    )
                }
            }
        }
        .background(Color.white)
        .overlay(Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Venue Selector

    private var venueSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(currentVenues, id: \.self) { venue in
                    Button(action: { selectedVenue = venue }) {
                        VStack(spacing: 2) {
                            Text(venue)
                                .font(.system(size: 14, weight: .bold))
                            Text("\(races.filter { $0.day == selectedDay && $0.venue == venue }.count)レース")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(selectedVenue == venue
                            ? Color(red: 0.36, green: 0.51, blue: 1.0)
                            : Color.secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle()
                                .fill(selectedVenue == venue
                                    ? Color(red: 0.36, green: 0.51, blue: 1.0)
                                    : Color.clear)
                                .frame(height: 2),
                            alignment: .bottom
                        )
                    }
                }
            }
        }
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }

    private func dateString(for day: RaceDay) -> String {
        let calendar = Calendar.current
        var date = Date()
        while calendar.component(.weekday, from: date) != 7 {
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        let sat = date
        let sun = calendar.date(byAdding: .day, value: 1, to: sat)!
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: day == .saturday ? sat : sun)
    }
}


// MARK: - RaceCard

struct RaceCard: View {
    let race: Race

    var body: some View {
        HStack(spacing: 14) {
            // グレード・レース番号
            VStack(spacing: 6) {
                Text(race.grade.displayText)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .frame(minWidth: 32)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(race.grade.color)
                    .cornerRadius(6)

                Text(race.raceNumber)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .frame(width: 44)

            // レース情報
            VStack(alignment: .leading, spacing: 5) {
                Text(race.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(race.distance)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(Color.secondary.opacity(0.5))
                    Text("馬場: \(race.condition)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(Color.secondary.opacity(0.5))
                    Text("\(race.horses.count)頭")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 発走時刻・矢印
            VStack(alignment: .trailing, spacing: 2) {
                Text(race.time)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Text("発走")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Sample Data

let sampleRaces: [Race] = [
    // ── 土曜日 ─────────────────────────────
    Race(day: .saturday, venue: "東京", raceNumber: "11R", name: "ジャパンカップ", grade: .g1,
         distance: "芝2400m", condition: "良", time: "15:40", horses: [
             Horse(number: 1, name: "イクイノックス",     odds: 1.8,  runningStyle: .stalker),
             Horse(number: 2, name: "リバティアイランド", odds: 3.2,  runningStyle: .midpack),
             Horse(number: 3, name: "タイトルホルダー",   odds: 5.1,  runningStyle: .front),
             Horse(number: 4, name: "ドウデュース",       odds: 6.3,  runningStyle: .midpack),
             Horse(number: 5, name: "スターズオンアース", odds: 8.7,  runningStyle: .midpack),
             Horse(number: 6, name: "ジャスティンパレス", odds: 12.4, runningStyle: .stalker),
             Horse(number: 7, name: "ソールオリエンス",   odds: 18.6, runningStyle: .midpack),
             Horse(number: 8, name: "パンサラッサ",       odds: 25.0, runningStyle: .front),
         ]),
    Race(day: .saturday, venue: "東京", raceNumber: "10R", name: "アルゼンチン共和国杯", grade: .g2,
         distance: "芝2500m", condition: "良", time: "14:55", horses: [
             Horse(number: 1, name: "ヒートオンビート",   odds: 2.3,  runningStyle: .stalker),
             Horse(number: 2, name: "ブレークアップ",     odds: 4.1,  runningStyle: .stalker),
             Horse(number: 3, name: "マイネルウィルトス", odds: 6.5,  runningStyle: .stalker),
             Horse(number: 4, name: "ユーキャンスマイル", odds: 8.2,  runningStyle: .midpack),
             Horse(number: 5, name: "プログノーシス",     odds: 11.0, runningStyle: .midpack),
             Horse(number: 6, name: "エフフォーリア",     odds: 15.5, runningStyle: .stalker),
             Horse(number: 7, name: "シャフリヤール",     odds: 22.0, runningStyle: .midpack),
             Horse(number: 8, name: "ナムラクレア",       odds: 31.0, runningStyle: .front),
         ]),
    Race(day: .saturday, venue: "東京", raceNumber: "9R", name: "オーロカップ", grade: .listed,
         distance: "芝1400m", condition: "良", time: "14:05", horses: [
             Horse(number: 1, name: "ライトクオンタム", odds: 2.0,  runningStyle: .stalker),
             Horse(number: 2, name: "タガノパッション", odds: 4.5,  runningStyle: .midpack),
             Horse(number: 3, name: "コナコースト",     odds: 7.2,  runningStyle: .stalker),
             Horse(number: 4, name: "ベルクレスタ",     odds: 9.5,  runningStyle: .midpack),
             Horse(number: 5, name: "ビジュノワール",   odds: 14.0, runningStyle: .closer),
             Horse(number: 6, name: "スタニングローズ", odds: 20.0, runningStyle: .midpack),
         ]),
    Race(day: .saturday, venue: "京都", raceNumber: "11R", name: "エリザベス女王杯", grade: .g1,
         distance: "芝2200m", condition: "良", time: "15:40", horses: [
             Horse(number: 1, name: "アカイイト",         odds: 3.1,  runningStyle: .midpack),
             Horse(number: 2, name: "ウインマリリン",     odds: 4.5,  runningStyle: .stalker),
             Horse(number: 3, name: "ジェラルディーナ",   odds: 5.8,  runningStyle: .midpack),
             Horse(number: 4, name: "ライラック",         odds: 7.3,  runningStyle: .midpack),
             Horse(number: 5, name: "ハーパー",           odds: 9.5,  runningStyle: .stalker),
             Horse(number: 6, name: "イズジョーノキセキ", odds: 14.0, runningStyle: .midpack),
             Horse(number: 7, name: "サリエラ",           odds: 20.0, runningStyle: .closer),
             Horse(number: 8, name: "モリアーナ",         odds: 28.5, runningStyle: .midpack),
         ]),
    Race(day: .saturday, venue: "京都", raceNumber: "9R", name: "白菊賞", grade: .open,
         distance: "芝1600m", condition: "良", time: "14:05", horses: [
             Horse(number: 1, name: "コナコースト",     odds: 2.0,  runningStyle: .stalker),
             Horse(number: 2, name: "モリアーナ",       odds: 3.5,  runningStyle: .midpack),
             Horse(number: 3, name: "タガノパッション", odds: 6.0,  runningStyle: .midpack),
             Horse(number: 4, name: "テンハッピーローズ", odds: 9.0, runningStyle: .front),
             Horse(number: 5, name: "ドゥアイズ",       odds: 13.0, runningStyle: .stalker),
             Horse(number: 6, name: "ソレイユヴィータ", odds: 20.0, runningStyle: .closer),
         ]),

    // ── 日曜日 ─────────────────────────────
    Race(day: .sunday, venue: "東京", raceNumber: "11R", name: "天皇賞（秋）", grade: .g1,
         distance: "芝2000m", condition: "良", time: "15:40", horses: [
             Horse(number: 1, name: "イクイノックス",     odds: 1.5,  runningStyle: .stalker),
             Horse(number: 2, name: "ダノンベルーガ",     odds: 4.0,  runningStyle: .stalker),
             Horse(number: 3, name: "ジャックドール",     odds: 5.5,  runningStyle: .front),
             Horse(number: 4, name: "ガイアフォース",     odds: 7.0,  runningStyle: .stalker),
             Horse(number: 5, name: "ヴェルトライゼンデ", odds: 9.5,  runningStyle: .midpack),
             Horse(number: 6, name: "アドマイヤハダル",   odds: 13.0, runningStyle: .midpack),
             Horse(number: 7, name: "ポタジェ",           odds: 19.0, runningStyle: .stalker),
             Horse(number: 8, name: "マリアエレーナ",     odds: 27.5, runningStyle: .stalker),
         ]),
    Race(day: .sunday, venue: "東京", raceNumber: "10R", name: "霜月ステークス", grade: .listed,
         distance: "ダ1400m", condition: "良", time: "14:55", horses: [
             Horse(number: 1, name: "レモンポップ",       odds: 2.5,  runningStyle: .front),
             Horse(number: 2, name: "テーオードレフォン", odds: 3.8,  runningStyle: .stalker),
             Horse(number: 3, name: "シャマル",           odds: 6.2,  runningStyle: .stalker),
             Horse(number: 4, name: "ゴルトベルク",       odds: 8.5,  runningStyle: .midpack),
             Horse(number: 5, name: "タガノビューティー", odds: 11.5, runningStyle: .midpack),
             Horse(number: 6, name: "スリーグランド",     odds: 17.0, runningStyle: .closer),
         ]),
    Race(day: .sunday, venue: "阪神", raceNumber: "11R", name: "宝塚記念", grade: .g1,
         distance: "芝2200m", condition: "良", time: "15:40", horses: [
             Horse(number: 1, name: "クロノジェネシス",   odds: 2.4,  runningStyle: .midpack),
             Horse(number: 2, name: "レイパパレ",         odds: 4.0,  runningStyle: .front),
             Horse(number: 3, name: "ユニコーンライオン", odds: 6.8,  runningStyle: .stalker),
             Horse(number: 4, name: "ディープボンド",     odds: 8.1,  runningStyle: .stalker),
             Horse(number: 5, name: "アリーヴォ",         odds: 11.2, runningStyle: .stalker),
             Horse(number: 6, name: "メロディーレーン",   odds: 18.9, runningStyle: .closer),
             Horse(number: 7, name: "キングオブコージ",   odds: 28.4, runningStyle: .midpack),
             Horse(number: 8, name: "サンレイポケット",   odds: 35.7, runningStyle: .midpack),
         ]),
    Race(day: .sunday, venue: "阪神", raceNumber: "9R", name: "西宮ステークス", grade: .open,
         distance: "芝1600m", condition: "稍重", time: "14:05", horses: [
             Horse(number: 1, name: "ジャスティンカフェ",   odds: 2.8,  runningStyle: .midpack),
             Horse(number: 2, name: "ウインカーネリアン",   odds: 4.2,  runningStyle: .stalker),
             Horse(number: 3, name: "マテンロウオリオン",   odds: 7.0,  runningStyle: .front),
             Horse(number: 4, name: "ダノンスコーピオン",   odds: 9.3,  runningStyle: .stalker),
             Horse(number: 5, name: "セリフォス",           odds: 12.5, runningStyle: .midpack),
             Horse(number: 6, name: "カテドラル",           odds: 22.0, runningStyle: .closer),
         ]),
]
