# SplitKana

分割かなキーボード。仕様は [SPEC.md](SPEC.md)。

**いまはフェーズ1**（SplitKanaKit + 確認用ホストアプリ）。キーボード拡張はまだ無い。

## 構成

**`Package.swift` が正。**`.xcodeproj` はリポジトリに置かない（Mac で各自が作る）。

```
SplitKana/
├─ Packages/SplitKanaKit/
│  ├─ Package.swift
│  └─ Sources/
│     ├─ SplitKanaCore/       Foundation だけに依存。UI も UIKit も入れない
│     │  ├─ Input/            KeyOutput・フリック表・フリック判定・濁点巡回・テキストバッファ
│     │  ├─ Layout/           キー配置・寸法計算・端末別レイアウト・ポップアップの置き場所
│     │  └─ Conversion/       かな漢字変換の抽象（フェーズ4まで空実装）
│     └─ SplitKanaUI/         SwiftUI。KeyboardView とキーの見た目だけ
├─ App/SplitKanaHost/         確認用ホストアプリ（画面に文字が出るだけ）
└─ SPEC.md
```

`Keyboard/`（拡張ターゲット）はフェーズ2で足す。

### なぜ Core と UI を分けるか

- **テストが Mac なしで走る。** ロジックは全部 Core にあり、Foundation しか使わないので
  Windows / Linux でも `swift test` が通る
- キーボード拡張はメモリ制限が厳しい（SPEC 4）。UI を差し替えたくなったとき、
  境界が引いてあれば Core はそのまま使える

**Core に入れてよいもの**：キー配置、寸法計算、フリック判定、濁点巡回、設定モデル、KeyOutput
**入れてはいけないもの**：SwiftUI / UIKit、`UITextDocumentProxy`、カード／島のモデル、ファイル保存

## Mac で動かす

`.xcodeproj` は入っていないので、最初に1回だけ作る。

1. **Xcode → File → New → Project → iOS → App**
   - Product Name: `SplitKanaHost`
   - Interface: SwiftUI / Language: Swift
   - 保存先: このリポジトリ直下（`SplitKana/`）
   - 「Create Git repository」のチェックは**外す**（もうリポジトリがある）
2. **File → Add Package Dependencies… → Add Local…** で `Packages/SplitKanaKit` を選ぶ
   - `SplitKanaCore` と `SplitKanaUI` の**両方**を `SplitKanaHost` ターゲットに追加する
3. Xcode が作ったテンプレートの `ContentView.swift` と `SplitKanaHostApp.swift` を削除（Move to Trash）
4. `App/SplitKanaHost/` の4ファイルをドラッグして追加
   - `SplitKanaHostApp.swift` / `HostRootView.swift` / `TranscriptView.swift` / `TypingStats.swift`
   - **「Copy items if needed」はオフ**、Target は `SplitKanaHost` にチェック
5. ターゲット設定
   - Minimum Deployments: **iOS 17.0**
   - iPhone Orientation: Landscape Left / Landscape Right（Portrait も付けてよい）
6. iPhone シミュレータか実機で実行し、**横向きにする**

生成された `.xcodeproj` は `.gitignore` に入れず、そのままコミットしてかまわない。
壊れたらこの手順で作り直せばよい、という位置づけにしてある。

## Windows / Linux でテストを走らせる

Core は Foundation しか使わないので、Mac がなくてもロジックのテストは全部走る。

```bash
scripts\swift-test.bat
```

**動作確認済み**：Swift 6.3.3 / VS Build Tools 17.14 / Windows SDK 10.0.26100 で36テスト全パス。

素の `swift test` は Windows では通らない（`link.exe`・`SDKROOT`・index store の3点で失敗する）。
スクリプトはそれを吸収しているだけで、中身と理由は
[docs/windows-swift.md](docs/windows-swift.md) に書いてある。toolchain の入れ方も同じファイル。

`SplitKanaUI` は中身が `#if canImport(SwiftUI)` で囲んであるため、
SwiftUI の無い環境では空モジュールとしてビルドが通る。
**裏を返すと UI のコンパイルエラーは Windows では出ない。**そこは Mac の仕事。

## Mac が無いうちに実機で試す（Web プロトタイプ）

`web/prototype.html` は、SplitKanaCore を JavaScript に移植した打鍵プロトタイプ。
**iPhone / iPad の Safari で開けば、Mac なしで今日から打てる。**

- 定数と計算式は Swift 側と同じ（`TUNING` / `BASE` / フリック表 / 濁点巡回 / ポップアップの置き場所）
- 大きさ・下端の浮かせ量・フリックしきい値・右パネル3列/4列を**その場で変えられる**
- 実効倍率・キー寸法・キーボード高・中央の空きを数値で読める

SPEC 11 の未決事項（`scale`、`bottomInset`、フリックのしきい値、複製列を残すか）は、
**ここで実測した値を入れる。**それが仕様書の指示でもある。

歯車ボタンから設定を開き、値を決めたら `SplitKanaCore` の
`DeviceClass.baseMetrics` と `KeyboardConfiguration` に反映する。

> Safari で開いたあと「ホーム画面に追加」しておくと、
> ブラウザの UI が消えて実際のキーボードに近い高さで試せる。

### ファイルの構成について

`web/prototype.html` は単体で開ける完全な HTML だが、
`<!-- ARTIFACT:BEGIN -->` 〜 `<!-- ARTIFACT:END -->` のマーカーで囲ってある。
ホスティング先が `<head>` を差し替える形式のときは、この範囲だけを抜き出して使う。
**このファイルが正で、抜き出したものは生成物。**直すときは必ずこちらを直す。

## フェーズ1でやること

**1週間これだけを毎日使う。**測るもの：

- 文字/分（画面上部に出る）
- 削除キーの回数（同上）
- 届かないキーの有無（これは打ってみて気づくしかない）

そのあと SPEC.md 11章の未決事項を埋める：`scale`、`bottomInset`、
右パネル3列/4列、フリック判定のしきい値。

## いま実装してあるもの

| | 状態 |
|---|---|
| フリック表（11キー × 5方向） | ✅ `Core/Input/FlickTable.swift` |
| フリック判定（しきい値 18pt、定数は `SplitKanaTuning`） | ✅ `Core/Input/FlickResolver.swift` |
| 濁点巡回（小書き → 濁点 → 半濁点） | ✅ `Core/Input/DakutenCycle.swift` |
| 寸法計算（コンテナ寸法から毎回計算・セーフエリア対応） | ✅ `Core/Layout/KeyboardGeometry.swift` |
| iPhone 横の分割レイアウト | ✅ |
| iPad 縦横 / iPad Split View | ✅（未実測。フェーズ2で詰める） |
| iPhone 縦の5列フォールバック | ✅ |
| 右パネル3列 / 4列の切り替え | ✅ `KeyboardConfiguration.showsDuplicateColumn` |
| 機能列のホスト差し替え | ✅ `.keyboardExtension` / `.thinkingApp` |
| フリックポップアップ（パネルの内側端に固定） | ✅ `KeyboardGeometry.popupPlacement` |
| カーソル移動 ◀▶ | ✅ ホストでも効く |
| 🌐 / 英数 | ⬜ 表示のみ（🌐 は拡張でしか動かせない） |
| かな漢字変換 | ⬜ プロトコルのみ（フェーズ4） |
| キーボード拡張 | ⬜ フェーズ2 |
| 設定パネル | ⬜ フェーズ3 |
| 触覚フィードバック | ⬜ フルアクセスが要るので保留（SPEC 4） |

### ポップアップの方式

**押したキーの隣ではなく、パネルの内側端に固定する。**

隣に開くと、右パネルの さ列 のポップアップが か列・あ列を覆ってしまう。
パネルの外（中央の空き）に固定すれば、どのキーを押してもキーは一切隠れない。
中央の空きに収まるよう1項目の幅を詰めるので、はみ出すこともない。
縦位置だけは押したキーの行に合わせて動く。

iPhone 縦（統合レイアウト）には中央の空きがないので、そこだけは従来どおり
キーの隣に開き、画面外へ出ないようクランプする。
