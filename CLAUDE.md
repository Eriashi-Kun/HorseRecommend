# Pakapick - 開発ガイド

## プロジェクト概要
競馬予想をゲーム感覚で楽しむiOSアプリ。AIが出走馬を分析し、本命・中穴・爆穴の3スタイルで予想を提供する。

## アーキテクチャ

### iOS (SwiftUI)
- **最小ターゲット**: iOS 26.2 (Xcode 26)
- **デザインテーマ**: Splatoon風 ダーク + ビビッドカラー (`SplatTheme.swift`)
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
| `Models.swift` | Race, Horse, Recommendation等のデータモデル |
| `RaceDTO.swift` | API JSON ↔ Swift モデル変換 |
| `NetworkRaceRepository.swift` | API通信・レース結果取得 |
| `MockRaceRepository.swift` | 開発用モックデータ |
| `PredictionTypeSelectView.swift` | ホーム画面（レース選択・予想タイプ選択） |
| `RaceSelectionView.swift` | レース一覧シート |
| `RecommendationResultView.swift` | 予想結果画面（スロット・レーダーチャート・シェア） |
| `HorseParameterView.swift` | レーダーチャート・トレイトバッジ |
| `ShareCardView.swift` | SNSシェア用カード画像 |
| `RewardedAdManager.swift` | AdMobリワード広告管理（5回まで無料） |
| `BannerAdView.swift` | AdMobバナー広告（予想結果画面下部） |
| `PredictionRecord.swift` | SwiftDataモデル（予想履歴） |
| `HistoryView.swift` | 予想履歴画面（着順ハイライト付き） |
| `NotificationManager.swift` | 週末プッシュ通知（土日8時） |
| `SplatTheme.swift` | カラー・スタイル定数 |
| `Config.swift` | 広告ユニットID・バックエンドURL |
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
- **テスト用バナーID**: `ca-app-pub-3940256099942544/2934735716`
- **テスト用リワードID**: `ca-app-pub-3940256099942544/1712485313`
- **注意**: 広告ユニット作成時「パートナーでの入札」はチェック不要（AdMobのみ運用）

## App Store情報
- **アプリ名**: Pakapick
- **Bundle ID**: `com.eriashi.HorseRecommend`
- **現在のバージョン**: v1.4（審査中）
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
