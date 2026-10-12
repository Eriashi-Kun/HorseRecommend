import Testing
import Foundation
@testable import HorseRecommend

// PlayerStats は XP・レベル・称号・連続複勝を records から計算する純粋なロジック。
// UI に依存しないので、ここが壊れるとマイページの数字が静かに狂う。

@MainActor
struct PlayerStatsXPCurveTests {

    @Test("レベル10と11の境界でXP傾斜が変わる（称号境界と一致させてある）")
    func xpCurveStepsAtTitleBoundary() {
        #expect(PlayerStats.xpToNextLevel(from: 10) == 25)
        #expect(PlayerStats.xpToNextLevel(from: 11) == 65)
    }

    @Test("Lv.100 は上限で、次レベルに必要なXPは0")
    func levelCapNeedsNoMoreXP() {
        #expect(PlayerStats.xpToNextLevel(from: 100) == 0)
    }

    @Test("XP 0 は Lv.1、次レベルまで25")
    func zeroXPIsLevelOne() {
        let r = PlayerStats.computeLevel(from: 0)
        #expect(r.level == 1)
        #expect(r.xpInLevel == 0)
        #expect(r.xpToNext == 25)
    }

    @Test("必要XPに1足りないとレベルは上がらない")
    func oneXPShortDoesNotLevelUp() {
        let r = PlayerStats.computeLevel(from: 24)
        #expect(r.level == 1)
        #expect(r.xpInLevel == 24)
    }

    @Test("必要XPにちょうど到達するとレベルが上がり、レベル内XPは0に戻る")
    func exactThresholdLevelsUp() {
        let r = PlayerStats.computeLevel(from: 25)
        #expect(r.level == 2)
        #expect(r.xpInLevel == 0)
    }

    @Test("XPを使い切らない分はレベル内XPとして残る")
    func remainderCarriesIntoLevel() {
        // Lv.1→2 に 25、Lv.2→3 に 25。60 XP なら Lv.3 で 10 余る
        let r = PlayerStats.computeLevel(from: 60)
        #expect(r.level == 3)
        #expect(r.xpInLevel == 10)
    }

    @Test("XPが莫大でも Lv.100 で止まる")
    func levelIsCappedAt100() {
        let r = PlayerStats.computeLevel(from: 10_000_000)
        #expect(r.level == 100)
        #expect(r.xpToNext == 0)
    }

    @Test("レベル内の進捗は xpInLevel / xpToNext")
    func xpProgressIsRatioWithinLevel() {
        // 予想1件（結果未取得）→ 10 XP。Lv.1 は 25 必要なので 10/25 = 0.4
        let stats = PlayerStats(records: [record(finishPosition: nil)])
        #expect(stats.xpInLevel == 10)
        #expect(stats.xpToNext == 25)
        #expect(stats.xpProgress == 0.4)
    }
}

@MainActor
struct PlayerStatsTitleTests {

    @Test("称号は10レベル刻みで切り替わる", arguments: [
        (1, "見習い"), (10, "見習い"),
        (11, "予想師"), (20, "予想師"),
        (21, "中堅予想師"), (31, "上級予想師"),
        (41, "エキスパート"), (51, "マスター"),
        (61, "神予想師"), (71, "伝説の予想師"),
        (81, "競馬の覇者"), (91, "競馬神"), (100, "競馬神"),
    ])
    func titleBoundaries(level: Int, expected: String) {
        #expect(PlayerStats.title(for: level) == expected)
    }
}

@MainActor
struct PlayerStatsAggregationTests {

    @Test("結果未取得の予想は pending に入り、resolved には数えない")
    func unresolvedCountsAsPending() {
        let stats = PlayerStats(records: [
            record(finishPosition: nil),
            record(finishPosition: nil),
            record(finishPosition: 1),
        ])
        #expect(stats.totalPredictions == 3)
        #expect(stats.resolvedCount == 1)
        #expect(stats.pendingCount == 2)
    }

    @Test("XPは予想数×10 + 複勝数×30。結果未取得でも予想分のXPは入る")
    func xpCountsPredictionsAndHits() {
        // 予想3件（うち複勝1件、1件は結果未取得）→ 3*10 + 1*30 = 60
        let stats = PlayerStats(records: [
            record(finishPosition: 1),
            record(finishPosition: 5),
            record(finishPosition: nil),
        ])
        #expect(stats.totalXP == 60)
    }

    @Test("複勝は3着まで。4着は複勝にならない")
    func hitMeansTopThree() {
        #expect(PlayerStats(records: [record(finishPosition: 3)]).hitCount == 1)
        #expect(PlayerStats(records: [record(finishPosition: 4)]).hitCount == 0)
    }

    @Test("結果取得済みが0件でも的中率は0除算にならない")
    func hitRateIsZeroWhenNothingResolved() {
        let stats = PlayerStats(records: [record(finishPosition: nil)])
        #expect(stats.resolvedCount == 0)
        #expect(stats.hitRate == 0)
    }

    @Test("的中率は結果取得済みのみを分母にする")
    func hitRateUsesResolvedAsDenominator() {
        // 複勝1件 / 結果取得済み2件 = 0.5（結果未取得1件は分母に入らない）
        let stats = PlayerStats(records: [
            record(finishPosition: 1),
            record(finishPosition: 8),
            record(finishPosition: nil),
        ])
        #expect(stats.hitRate == 0.5)
    }

    @Test("タイプ別成績も結果取得済みのみを数える")
    func typeStatsCountResolvedOnly() {
        let stats = PlayerStats(records: [
            record(finishPosition: 1, type: "固め"),
            record(finishPosition: nil, type: "固め"),
            record(finishPosition: 9, type: "爆穴"),
        ])
        #expect(stats.typeStats["固め"]?.total == 1)
        #expect(stats.typeStats["固め"]?.hits == 1)
        #expect(stats.typeStats["爆穴"]?.total == 1)
        #expect(stats.typeStats["爆穴"]?.hits == 0)
    }
}

@MainActor
struct PlayerStatsStreakTests {

    @Test("連続複勝は新しい順に数え、外れた時点で止まる")
    func streakStopsAtFirstMiss() {
        let now = Date()
        // 新しい順: 複勝, 複勝, 外れ, 複勝  → streak は 2 で止まる
        let stats = PlayerStats(records: [
            record(finishPosition: 1, savedAt: now),
            record(finishPosition: 2, savedAt: now.addingTimeInterval(-100)),
            record(finishPosition: 7, savedAt: now.addingTimeInterval(-200)),
            record(finishPosition: 3, savedAt: now.addingTimeInterval(-300)),
        ])
        #expect(stats.streak == 2)
    }

    @Test("最新が外れなら連続複勝は0")
    func streakIsZeroWhenLatestMissed() {
        let now = Date()
        let stats = PlayerStats(records: [
            record(finishPosition: 10, savedAt: now),
            record(finishPosition: 1, savedAt: now.addingTimeInterval(-100)),
        ])
        #expect(stats.streak == 0)
    }

    @Test("結果未取得のレコードは連続複勝の判定に混ざらない")
    func streakIgnoresUnresolved() {
        let now = Date()
        // 一番新しいのは結果未取得。これを外れ扱いすると streak が 0 になってしまう
        let stats = PlayerStats(records: [
            record(finishPosition: nil, savedAt: now),
            record(finishPosition: 1, savedAt: now.addingTimeInterval(-100)),
            record(finishPosition: 2, savedAt: now.addingTimeInterval(-200)),
        ])
        #expect(stats.streak == 2)
    }
}

// MARK: - Fixture

@MainActor
private func record(finishPosition: Int?,
                    type: String = "固め",
                    savedAt: Date = Date()) -> PredictionRecord {
    let r = PredictionRecord(
        raceId: "202605010101", raceName: "テストレース", venue: "東京",
        raceNumber: "1", day: "20260501", predictionType: type, weightsKey: "",
        picks: [PickData(horseNumber: 1, horseName: "テスト馬", odds: 3.0,
                         finishPosition: finishPosition)]
    )
    r.savedAt = savedAt
    return r
}
