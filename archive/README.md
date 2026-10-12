# archive

旧 `Developer/HorseRecommend/` （リポジトリのひとつ外側にあった入れ物）に
散在していた素材・旧コード。2026-10-12 の構成整理でここに取り込んだ。

**消す前に一度コミットしてあるので、不要になったら気軽に削除してよい。**
履歴から復元できる。

## backend-2026-05-10/

現行 `backend/` の旧版（最終更新 2026-05-10）。現行版とは中身が異なり、
`Dockerfile` / `fly.toml` / `recommender.py` / `tests/` を持たない。
Fly.io にデプロイされているのは現行 `backend/` の方。

## keiba-pro-api/

同系統の旧 API（最終更新 2026-05-24）。`Dockerfile` と `fly.toml` を持つ。
現行 `backend/` に統合されたと思われる。

## sounds-original/

アプリに入っている効果音の原本。日本語ファイル名のままで、どの音が
何なのかが分かるので残してある。**中身は md5 一致で完全に同一。**

| 原本 | アプリ内 (`HorseRecommend/`) |
|---|---|
| `コイン（チャリーン）.mp3` | `xp_gain.mp3` |
| `レベルアップ.mp3` | `level_up.mp3` |
| `ゲームクリア(壮大).mp3` | `title_up.mp3` |

## 重複メモ

`store/AppIcon.png` は `HorseRecommend/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
と md5 一致の同一ファイル（1024x1024）。
