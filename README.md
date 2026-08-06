# SplitKana

分割かなキーボード。仕様は [SPEC.md](SPEC.md)。

**いまはフェーズ1**（SplitKanaKit + 確認用ホストアプリ）。キーボード拡張はまだ無い。

## 構成

```
SplitKana/
├─ Packages/SplitKanaKit/     Swift Package。入力ロジックと KeyboardView の本体
│  ├─ Layout/                 キー配置・寸法計算・端末別レイアウト
│  ├─ Input/                  フリック判定・濁点巡回・キーイベント
│  ├─ Views/                  KeyboardView（SwiftUI）
│  └─ Conversion/             かな漢字変換の抽象（フェーズ4まで空実装）
├─ App/SplitKanaHost/         確認用ホストアプリ（画面に文字が出るだけ）
├─ SplitKana.xcodeproj
└─ SPEC.md
```

`Keyboard/`（拡張ターゲット）はフェーズ2で足す。

## 動かす

```bash
open SplitKana.xcodeproj
```

`SplitKanaHost` スキームを iPhone シミュレータ（または実機）で実行し、**横向きにする**。
中央にテキスト、左右にキーのクラスタが出る。

### プロジェクトファイルについて

`SplitKana.xcodeproj` は Xcode を使わずに手で書いてある（開発機が Windows のため）。
Xcode が開けない・壊れていると言う場合は、作り直したほうが早い：

1. Xcode → File → New → Project → iOS App
   - Product Name: `SplitKanaHost` / Interface: SwiftUI / Language: Swift
   - 保存先をこのリポジトリ直下にして、既存の `App/` を上書きしないよう注意
2. File → Add Package Dependencies → Add Local → `Packages/SplitKanaKit` を選ぶ
3. 生成されたテンプレートの `.swift` を消し、`App/SplitKanaHost/*.swift` をターゲットに追加
4. Deployment Target を iOS 17.0 に、向きは横（Landscape Left / Right）を有効に

### パッケージ単体のテスト

```bash
swift test --package-path Packages/SplitKanaKit
```

`Layout` / `Input` は UIKit に依存しないので、ロジックのテストは Xcode を開かずに走る。

## フェーズ1でやること

**1週間これだけを毎日使う。**測るもの：

- 文字/分（画面上部に出る）
- 削除キーの回数（同上）
- 届かないキーの有無（これは打ってみて気づくしかない）

そのあと SPEC.md 11章の未決事項を埋める：`scale`、`bottomInset`、
右パネル3列/4列、フリック判定のしきい値。

## 設計上、動かしてはいけない境界

`SplitKanaKit` は `KeyOutput` を出すだけで、テキストがどこへ行くかを知らない。

- **入れてよい**：キー配置、寸法計算、フリック判定、濁点巡回、KeyboardView、設定モデル
- **入れてはいけない**：`UITextDocumentProxy` への直接依存、カード／島のモデル、ファイル保存

この境界を守っているかぎり、フェーズ2の拡張は `KeyOutput` を `textDocumentProxy` に
流すだけで同じキーボードが動く。

## いま実装してあるもの

| | 状態 |
|---|---|
| フリック表（11キー × 5方向） | ✅ `Input/FlickTable.swift` |
| フリック判定（しきい値 18pt、定数は `SplitKanaTuning`） | ✅ `Input/FlickResolver.swift` |
| 濁点巡回（小書き → 濁点 → 半濁点） | ✅ `Input/DakutenCycle.swift` |
| 寸法計算（コンテナ寸法から毎回計算・セーフエリア対応） | ✅ `Layout/KeyboardGeometry.swift` |
| iPhone 横の分割レイアウト | ✅ |
| iPad 縦横 / iPad Split View | ✅（未実測。フェーズ2で詰める） |
| iPhone 縦の5列フォールバック | ✅ |
| 右パネル3列 / 4列の切り替え | ✅ `KeyboardConfiguration.showsDuplicateColumn` |
| 機能列のホスト差し替え | ✅ `.hostApp` / `.keyboardExtension` |
| フリックポップアップ（中央側へ横向きに開く） | ✅ `Views/FlickPopupView.swift` |
| かな漢字変換 | ⬜ プロトコルのみ（フェーズ4） |
| キーボード拡張 | ⬜ フェーズ2 |
| 設定パネル | ⬜ フェーズ3 |
| 触覚フィードバック | ⬜ フルアクセスが要るので保留（SPEC 4） |
