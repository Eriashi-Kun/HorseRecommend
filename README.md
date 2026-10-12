# Pakapick

競馬予想をゲーム感覚で楽しむ iOS アプリ。AI が出走馬を分析し、本命・中穴・爆穴の
3スタイルで予想を提供する。予想するたびに XP が入りレベルと称号が上がる。

- **公開中**: App Store（最新 v2.2.1）
- **バックエンド**: https://pakapick-api.fly.dev

## 構成

```
.
├── HorseRecommend/          iOS アプリ本体（SwiftUI / ターゲット名は履歴上の名前）
│   ├── App/                 エントリポイント・ルートビュー・設定
│   ├── Features/            画面単位
│   │   ├── Prediction/      予想フロー（種別選択 → レース選択 → 結果）
│   │   ├── Parameters/      予想パラメータのカスタマイズ
│   │   ├── History/         予想履歴（SwiftData）
│   │   └── MyPage/          レベル・称号・的中率
│   ├── Core/
│   │   ├── Models/          ドメインモデル・DTO
│   │   ├── Repositories/    データ取得（Network / Mock の2実装）
│   │   └── Engine/          予想ロジック
│   ├── Services/            広告・通知・サウンド
│   ├── DesignSystem/        SplatTheme（Splatoon 風ダーク + ビビッドカラー）
│   └── Resources/           Assets / Fonts / Sounds
├── HorseRecommend.xcodeproj
├── Info.plist               ターゲットの Info.plist（INFOPLIST_FILE が参照）
├── backend/                 FastAPI + netkeiba スクレイピング（Fly.io 東京）
├── docs/                    設計メモ・マーケティング資料
├── store/                   App Store 提出素材（スクショ・アイコン）
├── lp/                      ランディングページ
└── archive/                 旧実装・素材の原本（削除可。archive/README.md 参照）
```

アプリのソースは Xcode 16+ の**同期フォルダ**（`PBXFileSystemSynchronizedRootGroup`）
で管理している。`HorseRecommend/` 以下にファイルを置けば Xcode が自動で認識するので、
**ファイルの追加・移動で `project.pbxproj` を編集する必要はない。**

## 開発

### iOS

```sh
open HorseRecommend.xcodeproj
```

コマンドラインからビルドする場合、`xcode-select` が CommandLineTools を指しているので
`DEVELOPER_DIR` の指定が必要:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project HorseRecommend.xcodeproj -scheme HorseRecommend \
  -destination 'generic/platform=iOS Simulator' build
```

最小ターゲットは iOS 26.2（Xcode 26）。依存は SPM で Google Mobile Ads と
User Messaging Platform。

### バックエンド

```sh
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt pytest
.venv/bin/python -m pytest tests -v
.venv/bin/uvicorn main:app --reload
```

デプロイ:

```sh
cd backend && flyctl deploy
```

`backend/**` への push で GitHub Actions がテストを走らせる
（`.github/workflows/test.yml`）。

## 触ってはいけないもの

- **bundle id `com.eriashi.HorseRecommend`** — 変更すると App Store 上で別アプリに
  なり、既存ユーザーに更新が届かず AdMob の紐付けも切れる。表示名は `Info.plist` の
  `CFBundleDisplayName` で `Pakapick` にしてある。
- **Xcode のターゲット名・スキーム名** — 同じ理由。フォルダ名が `HorseRecommend` の
  ままなのは意図的。

## リリース

出荷したコミットにはタグを打つ。`v2.2.1` が現在の公開版。

```sh
git tag -a v2.3.0 -m "App Store 出荷版 v2.3.0" && git push origin v2.3.0
```
