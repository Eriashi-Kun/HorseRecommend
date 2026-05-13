# Pakapick - 開発ガイド

## プロジェクト概要
競馬予想をゲーム感覚で楽しむiOSアプリ。AIが出走馬を分析し、本命・中穴・爆穴の3スタイルで予想を提供する。

## アーキテクチャ

### iOS (SwiftUI)
- **最小ターゲット**: iOS 26.2 (Xcode 26)
- **デザインテーマ**: Splatoon風 ダーク + ビビッドカラー (`SplatTheme.swift`)
- **主要画面フロー**: `PredictionTypeSelectView` → `RaceSelectionView` → `RecommendInputView` → `RecommendationResultView`

### バックエンド (FastAPI + Render)
- **デプロイ先**: Render (無料プラン)
- **エンドポイント**:
  - `GET /races` - 本日のレース一覧（netkeibaスクレイピング）
  - `POST /recommend` - AI予想生成
- **AIエンジン**: Claude Haiku (`claude-haiku-4-5-20251001`)
- **データソース**: netkeiba.com（スクレイピング許可済み・iOS配信も確認済み）

## 主要ファイル

### iOS
| ファイル | 役割 |
|---|---|
| `Models.swift` | Race, Horse, Recommendation等のデータモデル |
| `RaceDTO.swift` | API JSON ↔ Swift モデル変換 |
| `NetworkRaceRepository.swift` | API通信 |
| `MockRaceRepository.swift` | 開発用モックデータ |
| `RecommendationResultView.swift` | 予想結果画面（スロット・レーダーチャート・シェア） |
| `HorseParameterView.swift` | レーダーチャート・トレイトバッジ |
| `ShareCardView.swift` | SNSシェア用カード画像 |
| `InterstitialAdManager.swift` | AdMob広告管理（2レースまで無料） |
| `SplatTheme.swift` | カラー・スタイル定数 |
| `Info.plist` | GADApplicationIdentifier等の設定（プロジェクトルート） |

### バックエンド
| ファイル | 役割 |
|---|---|
| `backend/main.py` | FastAPIエントリーポイント |
| `backend/scraper.py` | netkeiba スクレイピング |
| `backend/recommender.py` | Claude API呼び出し・予想ロジック |

## 広告設定
- **AdMob App ID**: `ca-app-pub-8763709237464698~1037543248`
- **広告ユニットID**: `ca-app-pub-8763709237464698/8850630257`
- **ロジック**: 1日2レースまで無料、3レース目から広告表示
- **テスト用ID**: `ca-app-pub-3940256099942544/4411468910`

## App Store情報
- **アプリ名**: Pakapick
- **Bundle ID**: `com.eriashi.HorseRecommend`
- **プライバシーポリシー**: https://www.notion.so/Pakapick-b2a33ec178d3470cb95467794b70185b
- **カテゴリ**: スポーツ / エンターテインメント

## 重要な注意事項
- `Info.plist` はプロジェクトルート（`.xcodeproj`と同階層）に置く。ソースフォルダ内に入れると二重処理エラーになる
- `GENERATE_INFOPLIST_FILE = NO` に設定済み
- バックエンドのAPIキーは Render の環境変数 `ANTHROPIC_API_KEY` で管理
- netkeibaのスクレイピングはEUC-JPエンコーディング

## 将来の拡張予定
- パラメータのカスタマイズ機能（騎手重視・過去データ重視など）
- 広告課金モデル（買い切り課金で広告オフ）
