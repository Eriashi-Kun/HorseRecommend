# Pakapick - 開発ガイド

## プロジェクト概要
競馬予想をゲーム感覚で楽しむiOSアプリ。AIが出走馬を分析し、本命・中穴・爆穴の3スタイルで予想を提供する。

## フォルダ構成

```
HorseRecommend/          iOS アプリ本体
├── App/                 エントリポイント・ルートビュー・設定
├── Features/            画面単位（Prediction / Parameters / History / MyPage）
├── Core/                Models / Repositories / Engine
├── Services/            広告・通知・サウンド
├── DesignSystem/        SplatTheme
└── Resources/           Assets / Fonts / Sounds
```

Xcode 16+ の**同期フォルダ**（`PBXFileSystemSynchronizedRootGroup`）で管理している。
`HorseRecommend/` 以下にファイルを置けば Xcode が自動認識するので、ファイルの追加・
移動で `project.pbxproj` を編集してはいけない（編集すると同期が壊れる）。

リポジトリ直下の `docs/` に設計メモとマーケ資料、`store/` に App Store 提出素材、
`lp/` に LP、`archive/` に旧実装がある。

## アーキテクチャ

### iOS (SwiftUI)
- **最小ターゲット**: iOS 26.2 (Xcode 26)
- **デザインテーマ**: Splatoon風 ダーク + ビビッドカラー (`DesignSystem/SplatTheme.swift`)
- **主要画面フロー**: `PredictionTypeSelectView` → `RaceSelectionView` → `RecommendationResultView`
- **状態管理**: `@Observable` / `ObservableObject` + SwiftData（予想履歴）

### バックエンド (FastAPI + Fly.io)
- **デプロイ先**: Fly.io 東京リージョン (nrt) - `https://pakapick-api.fly.dev`
- **デプロイ方法**: `cd backend && flyctl deploy`
- **エンドポイント**:
  - `GET /races` - 本日のレース一覧（netkeibaスクレイピング）
  - `POST /recommend` - AI予想生成
  - `GET /race/{race_id}/result` - レース結果取得（着順）
- **AIエンジン**: Claude Haiku (`claude-haiku-4-5-20251001`)
- **データソース**: netkeiba.com（スクレイピング許可済み・iOS配信も確認済み）
- **予想ロジック**: オッズでフィルタリング後にClaudeへ送信（固め≤10倍、中穴10-50倍、爆穴50倍超）

## 主要ファイル

### iOS
| ファイル | 役割 |
|---|---|
| `Core/Models/Models.swift` | Race, Horse, Recommendation等のデータモデル |
| `Core/Models/RaceDTO.swift` | API JSON ↔ Swift モデル変換 |
| `Core/Repositories/NetworkRaceRepository.swift` | API通信・レース結果取得 |
| `Core/Repositories/MockRaceRepository.swift` | 開発用モックデータ |
| `Features/Prediction/PredictionTypeSelectView.swift` | ホーム画面（レース選択・予想タイプ選択） |
| `Features/Prediction/RaceSelectionView.swift` | レース一覧シート |
| `Features/Prediction/RecommendationResultView.swift` | 予想結果画面（スロット・レーダーチャート・シェア） |
| `Features/Parameters/HorseParameterView.swift` | レーダーチャート・トレイトバッジ |
| `Features/Prediction/ShareCardView.swift` | SNSシェア用カード画像 |
| `Services/RewardedAdManager.swift` | AdMobリワード広告管理（5回まで無料） |
| `Services/BannerAdView.swift` | AdMobバナー広告（予想結果画面下部） |
| `Features/History/PredictionRecord.swift` | SwiftDataモデル（予想履歴） |
| `Features/History/HistoryView.swift` | 予想履歴画面（着順ハイライト付き） |
| `Services/NotificationManager.swift` | 週末プッシュ通知（土日8時） |
| `DesignSystem/SplatTheme.swift` | カラー・スタイル定数 |
| `App/Config.swift` | 広告ユニットID・バックエンドURL |
| `Info.plist` | GADApplicationIdentifier等の設定（プロジェクトルート） |

### バックエンド
| ファイル | 役割 |
|---|---|
| `backend/main.py` | FastAPIエントリーポイント |
| `backend/scraper.py` | netkeiba スクレイピング・レース結果取得 |
| `backend/recommender.py` | Claude API呼び出し・予想ロジック |

## 広告設定
- **AdMob App ID**: `ca-app-pub-8763709237464698~1037543248`
- **バナー広告ユニットID**: `ca-app-pub-8763709237464698/6270808180`（予想結果画面下部・常時表示）
- **リワード広告ユニットID**: `ca-app-pub-8763709237464698/5424630370`（6回目の予想から表示）
- **ロジック**: 1日5回まで無料、6回目以降はリワード広告視聴で1回分解放
- **真実の在処**: `HorseRecommend/Services/RewardedAdManager.swift` の `freeLimit`。
  ドキュメントやコミットメッセージではなくこの値を見ること。
  判定は `needsAd = predictionsToday >= freeLimit` なので「freeLimit 回まで無料、
  その次から広告」になる
- **履歴上の注意**: v1.2 のコミットメッセージは「1日3回無料、4回目から広告」と
  言っているが、これは `InterstitialAdManager.swift`（インタースティシャル広告）
  時代の仕様。v1.5 でリワード広告方式に置き換えた際に同ファイルは削除され、
  無料回数は 5 になった。古いコミットメッセージを仕様の根拠にしないこと
- **テスト用バナーID**: `ca-app-pub-3940256099942544/2934735716`
- **テスト用リワードID**: `ca-app-pub-3940256099942544/1712485313`
- **注意**: 広告ユニット作成時「パートナーでの入札」はチェック不要（AdMobのみ運用）

## App Store情報
- **アプリ名**: Pakapick
- **Bundle ID**: `com.eriashi.HorseRecommend`
- **現在のバージョン**: v2.2.1 / MARKETING_VERSION 2.21 / build 14（公開中・タグ `v2.2.1`）
- **サポートURL**: https://eriashi-kun.github.io（app-ads.txt配信用）
- **プライバシーポリシー**: https://www.notion.so/Pakapick-b2a33ec178d3470cb95467794b70185b
- **カテゴリ**: スポーツ / エンターテインメント

## 重要な注意事項
- `Info.plist` はプロジェクトルート（`.xcodeproj`と同階層）に置く。ソースフォルダ内に入れると二重処理エラーになる
- `GENERATE_INFOPLIST_FILE = NO` に設定済み
- バックエンドのAPIキーは Fly.io の環境変数 `ANTHROPIC_API_KEY` で管理（`flyctl secrets set ANTHROPIC_API_KEY=...`）
- netkeibaのスクレイピングはEUC-JPエンコーディング
- シミュレーターでSwiftDataスキーマ変更後はアプリ削除が必要（`xcrun simctl shutdown all && xcrun simctl erase all`）
- NavigationStackのtoolbarはiOS 26でビビッドカラーに染まるバグあり → カスタムタイトルバーで回避

## 将来の拡張予定（v1.5以降）
- 広告表示中にAI予想を裏で先読みしてロード待ちをゼロにする（`RecommendationViewModel`を外部注入に変更）
- サブスク課金（広告オフ）
