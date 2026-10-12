import Testing
import Foundation
@testable import HorseRecommend

// RecommendationEngine は候補馬の選定とスコア計算を担う。
// オッズ帯の閾値やスコアの重みが静かにずれると、予想の中身が変わってしまう。

@MainActor
struct CandidateSelectionTests {

    @Test("固めはオッズの低い順に最大3頭")
    func safePicksThreeLowestOdds() {
        let race = race(horses: [
            horse(1, odds: 8.0), horse(2, odds: 2.0),
            horse(3, odds: 4.0), horse(4, odds: 6.0),
        ])
        let picks = RecommendationEngine().recommendations(race: race, type: .safe)
        #expect(picks.count == 3)
        #expect(picks.map(\.horse.odds) == [2.0, 4.0, 6.0])
    }

    @Test("出走頭数が3頭未満でも落ちない")
    func safeHandlesFewerThanThreeHorses() {
        let race = race(horses: [horse(1, odds: 3.0), horse(2, odds: 9.0)])
        let picks = RecommendationEngine().recommendations(race: race, type: .safe)
        #expect(picks.count == 2)
    }

    @Test("中穴は5〜20倍のゾーンだけを拾う")
    func midRangeSelectsFiveToTwentyZone() {
        let race = race(horses: [
            horse(1, odds: 2.0), horse(2, odds: 6.0),
            horse(3, odds: 12.0), horse(4, odds: 40.0),
        ])
        let picks = RecommendationEngine().recommendations(race: race, type: .midRange)
        #expect(picks.map(\.horse.odds) == [6.0, 12.0])
    }

    @Test("中穴ゾーンが不在なら人気3番手以降にフォールバックする")
    func midRangeFallsBackWhenZoneIsEmpty() {
        let race = race(horses: [
            horse(1, odds: 1.5), horse(2, odds: 2.0), horse(3, odds: 3.0),
            horse(4, odds: 45.0), horse(5, odds: 60.0),
        ])
        let picks = RecommendationEngine().recommendations(race: race, type: .midRange)
        // 人気1,2番手を飛ばして3頭
        #expect(picks.map(\.horse.odds) == [3.0, 45.0, 60.0])
    }

    @Test("爆穴は15倍以上を対象にする")
    func longShotPoolStartsAtFifteen() {
        let race = race(horses: [
            horse(1, odds: 5.0, style: .midpack), horse(2, odds: 20.0, style: .midpack),
            horse(3, odds: 30.0, style: .midpack), horse(4, odds: 50.0, style: .midpack),
        ])
        let picks = RecommendationEngine().recommendations(race: race, type: .longShot)
        #expect(picks.map(\.horse.odds) == [20.0, 30.0, 50.0])
    }

    @Test("15倍以上が1頭もいなければオッズの高い順に3頭返す")
    func longShotFallsBackToHighestOdds() {
        let race = race(horses: [
            horse(1, odds: 2.0), horse(2, odds: 4.0),
            horse(3, odds: 6.0), horse(4, odds: 8.0),
        ])
        let picks = RecommendationEngine().recommendations(race: race, type: .longShot)
        #expect(picks.map(\.horse.odds) == [8.0, 6.0, 4.0])
    }

    @Test("人気順位はオッズ昇順の1始まり")
    func popularityRankIsOneBasedByOdds() {
        let race = race(horses: [
            horse(1, odds: 8.0), horse(2, odds: 2.0), horse(3, odds: 4.0),
        ])
        let picks = RecommendationEngine().recommendations(race: race, type: .safe)
        #expect(picks.map(\.popularityRank) == [1, 2, 3])
    }
}

@MainActor
struct ScoreCalculationTests {

    let engine = RecommendationEngine()

    @Test("オッズが低いほどスコアが高い（同じ脚質・同じ馬場）")
    func lowerOddsScoreHigher() {
        let r = race(horses: [])
        let favorite  = horse(1, odds: 1.5, style: .midpack)
        let outsider  = horse(2, odds: 10.0, style: .midpack)
        #expect(engine.calculateScore(horse: favorite, race: r, type: .safe) == 75)
        #expect(engine.calculateScore(horse: outsider, race: r, type: .safe) == 22)
    }

    @Test("ダートは逃げ馬を優遇する（芝より+10）")
    func dirtFavorsFrontRunners() {
        let h = horse(1, odds: 3.0, style: .front)
        let onDirt = engine.calculateScore(horse: h, race: race(horses: [], distance: "ダ1600"), type: .safe)
        let onTurf = engine.calculateScore(horse: h, race: race(horses: [], distance: "芝1600"), type: .safe)
        #expect(onDirt == 60)
        #expect(onTurf == 50)
    }

    @Test("道悪は追い込み馬を優遇し、ダートでは不利にする")
    func wetFavorsClosersAndDirtPenalizesThem() {
        let h = horse(1, odds: 3.0, style: .closer)
        let wetTurf = engine.calculateScore(horse: h, race: race(horses: [], distance: "芝2000", condition: "重"), type: .safe)
        let dryTurf = engine.calculateScore(horse: h, race: race(horses: [], distance: "芝2000", condition: "良"), type: .safe)
        let dryDirt = engine.calculateScore(horse: h, race: race(horses: [], distance: "ダ1200", condition: "良"), type: .safe)
        #expect(wetTurf == 58)
        #expect(dryTurf == 48)
        #expect(dryDirt == 43)
    }

    @Test("中穴ボーナスは5〜20倍の馬にだけ乗る")
    func midRangeBonusAppliesOnlyInZone() {
        let r = race(horses: [])
        let inZone  = horse(1, odds: 6.0, style: .midpack)
        let outside = horse(2, odds: 25.0, style: .midpack)
        #expect(engine.calculateScore(horse: inZone, race: r, type: .midRange) == 44)   // 34 + 10
        #expect(engine.calculateScore(horse: outside, race: r, type: .midRange) == 13)  // ボーナスなし
    }

    @Test("スコアは99を超えない")
    func scoreIsCappedAt99() {
        // 爆穴のスコア式は (1/オッズ)*300 なので低オッズだと簡単に100を超える
        let h = horse(1, odds: 1.5, style: .midpack)
        #expect(engine.calculateScore(horse: h, race: race(horses: []), type: .longShot) == 99)
    }

    @Test("スコアは1を下回らない")
    func scoreIsFlooredAt1() {
        let h = horse(1, odds: 1000.0, style: .front)
        #expect(engine.calculateScore(horse: h, race: race(horses: []), type: .longShot) == 1)
    }
}

// MARK: - Fixtures

@MainActor
private func horse(_ number: Int, odds: Double, style: RunningStyle = .midpack) -> Horse {
    Horse(number: number, name: "テスト馬\(number)", odds: odds, runningStyle: style,
          gate: number, sex: "牡", age: 4, jockey: "テスト騎手", weight: 460)
}

@MainActor
private func race(horses: [Horse],
                  distance: String = "芝2000",
                  condition: String = "良") -> Race {
    Race(raceId: "202605010101", day: "20260501", venue: "東京", raceNumber: "1",
         name: "テストステークス", grade: .g3, distance: distance,
         condition: condition, time: "15:40", horses: horses)
}
