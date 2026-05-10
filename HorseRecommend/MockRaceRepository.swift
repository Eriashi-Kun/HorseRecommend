import Foundation

// MARK: - MockRaceRepository

final class MockRaceRepository: RaceRepository {

    func fetchRaces() -> [Race] {
        return sampleRaces
    }

    func fetchCurrentRace() -> Race {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyyMMdd"
        let today = dateFmt.string(from: Date())

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let currentTime = timeFmt.string(from: Date())

        let todayRaces = sampleRaces.filter { $0.day == today }.sorted { $0.time < $1.time }
        if let next = todayRaces.first(where: { $0.time >= currentTime }) { return next }
        if let last = todayRaces.last { return last }

        let upcoming = sampleRaces.sorted { $0.day < $1.day || ($0.day == $1.day && $0.time < $1.time) }
        return upcoming.first ?? sampleRaces[0]
    }
}

// MARK: - Sample Data
// 今週と来週の土日を仮の日付で設定（実データはAPIから取得）

let sampleRaces: [Race] = [
    // ── 土曜日 ─────────────────────────────
    Race(day: "20260516", venue: "東京", raceNumber: "11R", name: "ジャパンカップ", grade: .g1,
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
    Race(day: "20260516", venue: "東京", raceNumber: "10R", name: "アルゼンチン共和国杯", grade: .g2,
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
    Race(day: "20260516", venue: "京都", raceNumber: "11R", name: "エリザベス女王杯", grade: .g1,
         distance: "芝2200m", condition: "良", time: "15:40", horses: [
             Horse(number: 1, name: "アカイイト",         odds: 3.1,  runningStyle: .midpack),
             Horse(number: 2, name: "ウインマリリン",     odds: 4.5,  runningStyle: .stalker),
             Horse(number: 3, name: "ジェラルディーナ",   odds: 5.8,  runningStyle: .midpack),
             Horse(number: 4, name: "ライラック",         odds: 7.3,  runningStyle: .midpack),
             Horse(number: 5, name: "ハーパー",           odds: 9.5,  runningStyle: .stalker),
             Horse(number: 6, name: "イズジョーノキセキ", odds: 14.0, runningStyle: .midpack),
         ]),
    // ── 日曜日 ─────────────────────────────
    Race(day: "20260517", venue: "東京", raceNumber: "11R", name: "天皇賞（秋）", grade: .g1,
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
    Race(day: "20260517", venue: "阪神", raceNumber: "11R", name: "宝塚記念", grade: .g1,
         distance: "芝2200m", condition: "良", time: "15:40", horses: [
             Horse(number: 1, name: "クロノジェネシス",   odds: 2.4,  runningStyle: .midpack),
             Horse(number: 2, name: "レイパパレ",         odds: 4.0,  runningStyle: .front),
             Horse(number: 3, name: "ユニコーンライオン", odds: 6.8,  runningStyle: .stalker),
             Horse(number: 4, name: "ディープボンド",     odds: 8.1,  runningStyle: .stalker),
             Horse(number: 5, name: "アリーヴォ",         odds: 11.2, runningStyle: .stalker),
             Horse(number: 6, name: "メロディーレーン",   odds: 18.9, runningStyle: .closer),
         ]),
    Race(day: "20260517", venue: "阪神", raceNumber: "9R", name: "西宮ステークス", grade: .open,
         distance: "芝1600m", condition: "稍重", time: "14:05", horses: [
             Horse(number: 1, name: "ジャスティンカフェ", odds: 2.8,  runningStyle: .midpack),
             Horse(number: 2, name: "ウインカーネリアン", odds: 4.2,  runningStyle: .stalker),
             Horse(number: 3, name: "マテンロウオリオン", odds: 7.0,  runningStyle: .front),
             Horse(number: 4, name: "ダノンスコーピオン", odds: 9.3,  runningStyle: .stalker),
             Horse(number: 5, name: "セリフォス",         odds: 12.5, runningStyle: .midpack),
             Horse(number: 6, name: "カテドラル",         odds: 22.0, runningStyle: .closer),
         ]),
]
