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
  - `GET /find_race` - date/venue/race_number から race_id を検索
  - `POST /parse_ticket_vision` - 馬券画像（base64）をClaude Sonnetで解析
  - `POST /parse_result_html` - デバイスが取得したnetkeibaのHTMLをパース（Fly.ioのIPがブロックされるため）
- **AIエンジン**: 予想生成=Claude Haiku (`claude-haiku-4-5-20251001`) / 馬券OCR=Claude Sonnet (`claude-sonnet-4-6`)
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
| `BannerAdView.swift` | AdMobバナー広告（予想結果・マイページ下部） |
| `PredictionRecord.swift` | SwiftDataモデル（予想履歴） |
| `HistoryView.swift` | 予想履歴画面（着順ハイライト付き） |
| `MyPageView.swift` | マイページ（レベル・XP・称号・的中率統計） |
| `PlayerStats.swift` | XP/レベル計算ロジック（Lv1-100、称号10段階） |
| `UserWeightsManager.swift` | カスタマイズ重み管理（騎手・可愛さ・かっこよさ・デカさ） |
| `ParameterCustomizeView.swift` | カスタマイズ画面 |
| `SoundManager.swift` | サウンド再生（XP増加・レベルアップ・称号進化） |
| `NotificationManager.swift` | 週末プッシュ通知（土日8時） |
| `SplatTheme.swift` | カラー・スタイル定数 |
| `Config.swift` | 広告ユニットID・バックエンドURL |
| `Info.plist` | GADApplicationIdentifier等の設定（プロジェクトルート） |
| `TicketRecord.swift` | SwiftDataモデル（馬券履歴・BetEntry・払戻判定ロジック） |
| `TicketParser.swift` | TicketParserError定義 |
| `TicketScanView.swift` | 馬券スキャン画面（PhotosPicker→Claude Vision→プレビュー→保存） |
| `TicketListView.swift` | 馬券一覧・損益サマリー・結果自動取得 |
| `TicketEditView.swift` | 馬券編集画面（TicketDraft）・全4パターン対応（ながし/ボックス/フォーメーション/通常） |

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
- **現在のバージョン**: v3.0開発中 / v2.1（審査中）/ v2.0（配信中）
- **サポートURL**: https://eriashi-kun.github.io（app-ads.txt配信用）
- **マーケティングURL**: https://eriashi-kun.github.io
- **プライバシーポリシー**: https://www.notion.so/Pakapick-b2a33ec178d3470cb95467794b70185b
- **カテゴリ**: スポーツ / エンターテインメント

## 重要な注意事項
- `Info.plist` はプロジェクトルート（`.xcodeproj`と同階層）に置く。ソースフォルダ内に入れると二重処理エラーになる
- `GENERATE_INFOPLIST_FILE = NO` に設定済み
- バックエンドのAPIキーは Fly.io の環境変数 `ANTHROPIC_API_KEY` で管理（`flyctl secrets set ANTHROPIC_API_KEY=...`）
- netkeibaのスクレイピングはEUC-JPエンコーディング
- シミュレーターでSwiftDataスキーマ変更後はアプリ削除が必要（`xcrun simctl shutdown all && xcrun simctl erase all`）
- NavigationStackのtoolbarはiOS 26でビビッドカラーに染まるバグあり → カスタムタイトルバーで回避

## ブランチ構成
- `feature/v2.0` — レベル・XPシステム・マイページ・カスタマイズ拡充（配信中）
- `feature/v2.1` — バックグラウンド結果取得・的中時XPバナー・馬番修正（審査中）
- `main` — 最新リリース済みコード

## 重要な実装メモ
- `#if !SCREENSHOTS` フラグ: スクリーンショット撮影時にバナー広告を非表示にする。Xcode Build Settings → Other Swift Flags → Debug に `-DSCREENSHOTS` を追加して使用
- XPカーブは称号の境界（10レベル刻み）に合わせて非線形設計（`PlayerStats.xpToNextLevel`参照）
- バナー広告は予想結果画面・マイページの ZStack 直下に `safeAreaInset` で追加（NavigationStack の外に置くと push 先の画面にも伝播するため注意）

### 画面遷移設計
| 遷移 | 方式 | 理由 |
|---|---|---|
| ホーム → マイページ | `.sheet` | 横並びの別画面 |
| マイページ → 馬券管理 | `navigationDestination`（MyPageView の NavigationStack 内） | ドリルダウン |
| 馬券管理 → 馬券編集 | `navigationDestination` | ドリルダウン |
| 馬券管理 → 馬券スキャン | `.fullScreenCover` | タスクフロー・誤閉じ防止 |
| TicketScanView → TicketEditView | `navigationDestination`（TicketScanView の NavigationStack 内） | ドリルダウン |
- タイトルバーはすべてカスタム実装。`.toolbar(.hidden, for: .navigationBar)` で system bar を非表示
- タイトルを確実にセンタリングするには `ZStack { Text(title); HStack { 左ボタン; Spacer(); 右ボタン } }` パターンを使う（Spacerだけだと幅が違う時にズレる）

### 馬券管理（v3.0）固有メモ
- **race_id の形式**: `{year}{venue_code}{kaisai_round:02d}{kaisai_day:02d}{race_num:02d}`。表示日付（5/23等）ではなく開催回・日（2回9日）でエンコードされる。OCRで日付がズレても race_id が正しければ払戻取得は成功する
- **betType コード**: EXACTA=馬単, TRIFECTA=三連単, TRIO=三連複, QUINELLA=馬連, QUINELLA PLACE=ワイド, WIN=単勝, PLACE=複勝。馬券左上の英語コードが最優先（日本語表記より正確）
- **払戻結果取得**: Fly.ioのIPがnetkeibaにブロックされるため、デバイスがHTMLを取得してバックエンドの `/parse_result_html` に送るアーキテクチャ
- **TicketDraft**: スキャン前確認（TicketScanView）と保存済み編集（TicketListView）・手動入力（TicketListView）の3箇所で共有する編集用モデル。`generatedBets` でパターン別に買い目を自動生成。`totalAmount` は保存時に必ず `calcTotal` を使うこと（stored var のため 0 のままになる）
- **TicketEditView の再利用**: `title` / `confirmLabel` パラメータで「内容を修正」「確定」と「馬券を入力」「保存」を切り替え
- **通常パターンの手動入力**: `originalBets` が空かつ非単勝複勝の場合、N頭選択で1組自動確定→グリッドリセット→複数組追加可能。AI読み取り済みは `originalBets` 非空なので読み取り結果を表示
- **出馬表未公開レース**: `horses` が空でもレースをキャッシュに登録（`missing name or horses` でスキップしない）。iOS側では `race.horses.isEmpty` を検知して「出走馬確定前」グレーアウト表示
- **safe subscript**: `Array[safe:]` は `RecommendationViewModel.swift` に定義済み。他のファイルに重複定義しないこと

## 将来の拡張予定

### v3.0: 馬券管理（開発中）
- ✅ Claude Sonnet Vision でスキャン・OCR
- ✅ 馬券一覧・損益サマリー
- ✅ 払戻額自動取得（レース結果確定後）
- ✅ 全パターン手動編集（ながし/ボックス/フォーメーション/通常）
- ✅ 保存済み馬券の修正・削除
- ✅ 手動入力画面（「手動入力」「AIスキャン」2ボタン）
- ✅ 出馬表未公開レースの表示（「出走馬確定前」グレーアウト）
- 🔲 AIスキャン課金ゲート（初回1回無料 → サブスク）

### v3.1: サブスク課金（予定）
- **内容**: AIスキャン無制限 + 広告カット
- **価格**: 月額300〜500円想定
- **初回体験**: AIスキャン1回無料（UserDefaultsでフラグ管理）
- **実装**: StoreKit 2

### v3.2: 券種レコメンド（課金機能）
- 予算・目標リターン・リスク許容度をボタン選択式で入力
- AIが最適な買い目（単勝/複勝/馬連/三連複等）と点数を提案
