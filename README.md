# SplitKana

分割かなキーボード。仕様は [SPEC.md](SPEC.md)。

**いまはフェーズ2まで完了**（SplitKanaKit + 確認用ホストアプリ + キーボード拡張 + 設定パネル）。
全アプリで使える状態。かな漢字変換は `feature/kana-kanji-conversion` ブランチで実装済み・実機未検証。

## 構成

**`Package.swift` と `project.yml` が正。**`.xcodeproj` は `xcodegen` の生成物。

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
├─ Keyboard/                  キーボード拡張（KeyOutput を textDocumentProxy に流すだけ）
└─ SPEC.md
```

### なぜ Core と UI を分けるか

- **テストが Mac なしで走る。** ロジックは全部 Core にあり、Foundation しか使わないので
  Windows / Linux でも `swift test` が通る
- キーボード拡張はメモリ制限が厳しい（SPEC 4）。UI を差し替えたくなったとき、
  境界が引いてあれば Core はそのまま使える

**Core に入れてよいもの**：キー配置、寸法計算、フリック判定、濁点巡回、設定モデル、KeyOutput
**入れてはいけないもの**：SwiftUI / UIKit、`UITextDocumentProxy`、カード／島のモデル、ファイル保存

## Mac で動かす

`.xcodeproj` は [xcodegen](https://github.com/yonaskolb/XcodeGen) でリポジトリ直下の
`project.yml` から生成する。**`project.yml` が正で、`.xcodeproj` は生成物。**
壊れたら作り直せばよいので、そのままコミットしてかまわない。

```bash
brew install xcodegen   # 初回のみ
xcodegen generate       # SplitKana.xcodeproj を生成／更新
```

`project.yml` には `SplitKanaHost` ターゲット（iOS 17.0、Landscape 中心）と、
ローカルパッケージ `Packages/SplitKanaKit`（`SplitKanaCore` / `SplitKanaUI`）への依存が
定義してある。ソースを追加・削除したときは `xcodegen generate` をやり直すだけでよく、
Xcode 上でファイルをドラッグする操作は不要。

シミュレータビルドの確認:

```bash
xcodebuild -project SplitKana.xcodeproj -scheme SplitKanaHost \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3.1' build
```

実機での動作確認は `SplitKana.xcodeproj` を Xcode で開いてシミュレータ／実機を選び実行する
（**横向きにする**）か、CLI からシミュレータを起動する:

> **⌘R で「Choose an app to run」が出たら**、スキームが `SplitKanaKeyboard` になっている。
> 拡張は単体で起動できないので、ツールバーのスキーム選択で **`SplitKanaHost`** を選ぶ。
> 拡張も一緒にビルドされて同梱される。
> `SplitKanaCore` / `SplitKanaUI` / `SplitKanaKeyboard` のスキームは Xcode が勝手に作るもので、
> 選んでも起動できない。気になるなら Product → Scheme → Manage Schemes… の
> 「Autocreate schemes」を切る。

```bash
xcrun simctl boot "iPhone 16 Pro"
open -a Simulator
xcrun simctl install booted /path/to/SplitKanaHost.app   # xcodebuild が吐いた .app
xcrun simctl launch booted com.splitkana.host
```

> Xcode 26 / Swift 6.2 では `import Foundation` だけでは `CGRect` 等が暗黙に
> 使えなくなっている。`SplitKanaCore` 側は `#if canImport(CoreGraphics) import CoreGraphics #endif`
> を添えて対応してあるので、Windows/Linux（CoreGraphics が無い環境）には影響しない。

## キーボードを有効にする

⌘R でアプリを入れると拡張も同梱される。そのあと端末側で1回だけ：

**設定 → 一般 → キーボード → キーボード → 新しいキーボードを追加 → 「分割かな」**

文字入力中に 🌐 を長押しして切り替える。

- **🌐 は必須**。これが無いと他のキーボードに戻れなくなる（SPEC 2.2）
- フルアクセスは要求していない（`RequestsOpenAccess = false`）。
  そのぶん触覚フィードバックは使えない（SPEC 4）
- パスワード欄では純正キーボードに戻る。音声入力も使えない。いずれも仕様

> **署名は1年で切れる。**切れるとキーボードが使えなくなり、
> 入れ直すのに Mac が要る。無料の Apple ID だと7日で切れる。

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

**これらは全部、実機の ⚙ キーで調整できる。**コードを直す必要はない。
機能列の ⚙（上から2番目）を押すと設定パネルが開く。

| 調整できるもの | 範囲 |
|---|---|
| 大きさ（倍率） | 0.60〜1.45 |
| 上の余白（キーの大きさを変えずに全体の高さを変える） | 0〜80pt |
| 下の浮き | 0〜80pt |
| 左右位置（左右パネルを内外に寄せる） | 0〜120pt |
| フリック判定のしきい値 | 6〜40pt |
| 右パネル 3列 / 4列 | トグル |

**値は端末クラスごとに別々に保存される**（iPhone 横 / iPhone 縦 / iPad 横 / iPad 縦）。
iPad 横で詰めても iPhone 縦には影響しない。保存先は拡張自身の `UserDefaults`
（App Group はフルアクセスが要るので使わない。SPEC 4）。

分割時はパネルが中央の空きに開くので、調整しながら打てる。
iPhone 縦は中央の空きが無いのでキーボードに重ねて開き、その間キーは反応しない。

既定値そのものを変えたいときは `KeyboardConfiguration` の `defaultScale` /
`defaultBottomInset` と `DeviceClass.baseMetrics` に書き戻す。現在の既定は **0.80 / 0pt**。

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
| 両手の親指の同時押し | ✅ `KeyboardGeometry.hitTest` + `MultiTouchOverlay` |
| カーソル移動 ◀▶ | ✅ ホストでも効く |
| 🌐 | ✅ 拡張で動く（機能列は 🌐 / ⚙ / ◀ / ▶） |
| かな漢字変換 | 🔸 AzooKey。空白で候補送り・改行で確定。**実機未検証** |
| キーボード拡張 | ✅ `Keyboard/`（iPad 実機で確認済み） |
| 設定パネル | ✅ 拡張内に ⚙ で開く。端末クラス別に保存 |
| 触覚フィードバック | ⬜ フルアクセスが要るので保留（SPEC 4） |

### ポップアップの方式

**押したキーの隣ではなく、パネルの内側端に固定する。**

隣に開くと、右パネルの さ列 のポップアップが か列・あ列を覆ってしまう。
パネルの外（中央の空き）に固定すれば、どのキーを押してもキーは一切隠れない。
中央の空きに収まるよう1項目の幅を詰めるので、はみ出すこともない。
縦位置だけは押したキーの行に合わせて動く。

iPhone 縦（統合レイアウト）には中央の空きがないので、そこだけは従来どおり
キーの隣に開き、画面外へ出ないようクランプする。
