---
name: v1.5 Implementation Plan
description: Features planned for v1.5 release
type: project
---

広告表示中にAIを裏で先読みしてロード時間をゼロにするUX改善。

**Why:** 広告→AI読み込み画面の二段階待ちがUX的に長く感じる。広告中に並行してAI予想を生成しておくことで、広告終了後即時結果表示できる。

**How to apply:** 
- `RecommendationViewModel` を `PredictionTypeSelectView` で事前生成し `.load()` を開始
- `@StateObject` → `@ObservedObject` に変更し外部から渡せるようにする
- `.task` 内で `vm.isLoading` が true なら Combine の `$isLoading` を監視して待つ（ロード済みなら即アニメーション）
- 無料枠（ad不要）でも同様に navigate 前にロード開始することで全体的に速くなる
- `navigationDestination` に `pendingVM` を渡す
