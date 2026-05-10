# HorseRecommend - CLAUDE.md

## プロジェクト概要

競馬の買い目をレコメンドする iOS アプリ（SwiftUI）。
ユーザーがレース・モード・予算・券種・軸馬を選択すると、買い目を提案する。

- 「おまかせ」機能は廃止。券種はユーザーが手動選択する
- 予算上限はファーストスコープで 9,900 円（4 桁）
- 100 円単位で購入。可能な限り予算ぴったりに使い切る
- モードは馬の選定にのみ使用し、券種には影響しない

## ディレクトリ構成

```
HorseRecommend/HorseRecommend/
├── HorseRecommendApp.swift    # @main エントリポイント
├── HomeView.swift             # 未使用・削除候補
├── RaceSelectionView.swift    # レース選択画面 + Race / Horse モデル
├── RecommendInputView.swift   # 条件入力画面（メイン）
├── ResultView.swift           # 買い目結果表示画面 + BuyingStyle / BettingInstruction
├── BettingEngine.swift        # 買い目生成ロジック全体（UIから分離）
├── HorseIcons.swift           # モード別馬アイコン（純 SwiftUI 描画）
└── Assets.xcassets/
```

## 画面フロー

```
HorseRecommendApp（起動時に最近傍レースを自動選択）
    └── RecommendInputView     # メイン画面
            ├── シート: RaceSelectionView（シート内完結）
            └── NavigationDestination: ResultView
```

### RecommendInputView のサブ View

```
RecommendInputView
├── RaceInfoCard           # レース情報（タップでRaceSelectionViewをシート起動）
├── ModeSelectionSection   # 固め / 中穴 / ロマン の3択
├── BudgetInputSection     # 予算入力（100円単位バリデーション・自動丸め）
├── TicketSettingSection   # 券種チェックボックス（常時表示・複数選択）
├── PivotHorseSection      # 軸馬選択（馬番グリッド、タップ選択）
└── BeginnerHintCard       # 初心者向けヒント
```

## データモデル

```swift
// RaceSelectionView.swift
struct Horse: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let odds: Double
    let runningStyle: RunningStyle  // .front / .stalker / .midpack / .closer
}

struct Race: Identifiable {
    let id = UUID()
    let day: RaceDay       // .saturday / .sunday
    let venue: String      // 例: "東京"
    let raceNumber: String // 例: "11R"
    let name: String
    let grade: RaceGrade   // .g1 / .g2 / .g3 / .listed / .open / .special
    let distance: String   // 例: "芝2400m"
    let condition: String  // 例: "良"
    let time: String       // 例: "15:40"
    let horses: [Horse]
}

// RecommendInputView.swift
enum RecommendMode: String, CaseIterable {
    case safe = "固め"
    case balanced = "中穴"
    case romantic = "ロマン"
}

// ResultView.swift
enum BuyingStyle {
    case single([Horse])
    case nagashi(axis: [Horse], opponents: [Horse])
    case box(horses: [Horse])
    case formation(first: [Horse], second: [Horse], third: [Horse])
}

struct BettingInstruction: Identifiable {
    let id = UUID()
    let ticketLabel: String
    let style: BuyingStyle
    let combinationCount: Int
    var amountPerCombination: Int = 100
    var totalAmount: Int { combinationCount * amountPerCombination }
}
```

## 状態管理

`@State` / `@Binding` のみ。ViewModel・ObservableObject・EnvironmentObject は使用しない。

```swift
// RecommendInputView の状態（全量）
@State private var selectedMode: RecommendMode = .balanced
@State private var budget = "1000"
@State private var selectedTickets: Set<String> = ["wide", "quinella"]  // デフォルト選択
@State private var pivotHorse: Horse? = nil
@State private var showRaceSelection = false
@State private var navigateToResult = false
```

## 買い目ロジック（BettingEngine.swift）

ロジックは `BettingEngine.swift` に集約。UI ファイルは変更しない。

### サービス構成

| クラス | 役割 |
|---|---|
| `HorseScoringService` | オッズ・脚質・馬場からスコア算出 |
| `ModeStrategy` | モード別の馬ソート順決定 |
| `BetTypeSelector` | 選択券種リストを正規化（ユーザー手動選択のみ） |
| `BetGenerator` | 券種ごとの買い目生成（`[BettingInstruction]` を返す） |
| `BudgetAllocator` | 券種ごとの予算按分・余り吸収 |
| `ResultCommentGenerator` | 結果コメント生成 |
| `PredictionEngine` | 上記を統合して `predict()` を提供 |

### モード別馬ソート

| モード | ソート方針 |
|---|---|
| 固め | スコア降順（人気馬優先） |
| 中穴 | オッズ 5〜20 倍の馬を優先、次いでスコア降順 |
| ロマン | 最高スコア馬をアンカーに、残りは 15 倍以上の穴馬を優先 |

### 券種別ルール

| 券種 | 形式 | 最大点数 | 備考 |
|---|---|---|---|
| 単勝 | 1通りのみ | 1 | 軸馬 or 最上位馬 |
| 複勝 | 1通りのみ | 1 | 軸馬 or 最上位馬 |
| ワイド | 流し / BOX | 流し 5、BOX 4頭(6通り) | 予算に応じて 3〜6通り |
| 馬連 | 流し / BOX | 流し 6、BOX 5頭(10通り) | 予算に応じて 4〜10通り |
| 馬単 | マルチ流し | 最大 12通り(6頭×表裏) | 馬連より攻めた券種 |
| 三連複 | 流し / BOX | 流し 6頭(15通り)、BOX 6頭(20通り) | 広めに買う |
| 三連単 | 流し / フォーメーション | 最大 60通り | 1点 100円固定 |

### 三連単の予算使い切りロジック

三連単は 1 点 100 円固定のため、`budget / 100` 通り購入できる。
60 通りの上限を超える予算が割り当てられた場合、**抑えフォーメーションを追加**して使い切る。

例）予算 9,900 円・三連単のみ選択：
- 本線：N×(N-1) ≤ 60 の最大値（N=8 → 56 通り × 100円 = 5,600円）
- 抑え：残り 43 通り × 100円 = 4,300円
- 合計：99 通り / 9,900円 ✓

### 予算配分

- 券種ごとにウェイト比で按分（単複 1.5、ワイド 1.2、馬連 1.0、馬単 0.8、三連複 0.7、三連単 0.5）
- Step1：ウェイト按分の初期金額（1点あたり上限でクランプ）
- Step2：Greedy で点数の少ない券種から 100 円ずつ追加
- Step3：Pair swap（+100/-100）で残りを吸収
- 余り吸収の優先順：三連単追加 → 三連複追加 → 馬単追加 → 馬連/ワイド増額 → 単複増額

### 1点あたり上限

| 券種 | 上限 |
|---|---|
| 単勝・複勝 | 3,000円 |
| ワイド | 1,000円 |
| 馬連 | 800円 |
| 馬単 | 500円 |
| 三連複 | 300円 |
| 三連単 | 100円（固定） |

### 軸馬ロジック

- 軸馬未選択: モード別ソート後の先頭馬を自動使用
- 軸馬選択時: 流しの軸・フォーメーション 1 着・BOX の必須馬として使用
- `others = sorted.filter { $0.id != axis.id }` で相手馬リストを構築
- 表示順は必ず馬番昇順（`.sorted { $0.number < $1.number }`）

## 命名規則

| 対象 | 規則 | 例 |
|---|---|---|
| 型（struct/enum） | UpperCamelCase | `RecommendMode`, `BettingInstruction` |
| プロパティ・変数 | lowerCamelCase | `selectedMode`, `selectedTickets` |
| 画面 View | `〇〇View` | `ResultView` |
| カード系 View | `〇〇Card` | `RaceInfoCard`, `BeginnerHintCard` |
| セクション系 View | `〇〇Section` | `ModeSelectionSection` |
| ボタン系 View | `〇〇Button` | — |
| ファイル内の区切り | `// MARK: - 説明` | `// MARK: - BetGenerator` |

## Preview

```swift
#Preview {
    NavigationStack {
        RecommendInputView(race: sampleRaces[0])
    }
}
```

## 既知の課題・今後の対応

| 優先度 | 内容 | 状態 |
|---|---|---|
| 中 | レース選択シートで選んだレースが RecommendInputView に反映されない | 未対応（シート内フローとして許容中） |
| 低 | `HomeView` が未使用 | 削除候補 |
| 低 | サンプルデータのみ（API連携なし） | 意図的・将来対応 |
| 低 | テストコードなし | 意図的 |
