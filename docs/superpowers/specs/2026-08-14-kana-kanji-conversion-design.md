# かな漢字変換 — 設計

2026-08-14

## なぜ作るか

キーボード拡張は iPad 実機で動くようになったが、**かな入力しかできない。**
漢字にするには純正キーボードへ切り替えるしかなく、常用に耐えない。

SPEC 5.3 は「かな入力のままで足りる可能性を実使用で確かめてから入れる」としていた。
フェーズ2の実使用を経て、**必要と判断された。**ここでその判断を実装に落とす。

## 範囲

**入るもの**：変換エンジンの導入、変換の状態機械、候補表示、
空白キーでの候補送り・改行での確定（SPEC 5.2）、`setMarkedText` による未確定表示。

**入らないもの**：英数 QWERTY モード。あれは寸法モデルの変更を伴う別の部分系で、
別途 設計 → 計画 → 実装 で回す。キー配置には本設計では一切手を入れない
（空白キーに左フリックを足す1点を除く）。

## 1. 依存の置き場所

**AzooKeyKanaKanjiConverter は `Packages/SplitKanaKit` に入れない。**
`Keyboard/` ターゲットの依存として `project.yml` に書く。

README はこう書いている。

> Core は Foundation しか使わないので、Mac がなくてもロジックのテストは全部走る。

SplitKanaKit に AzooKey を足すと、Windows での依存解決が失敗し、
**51件のテストが1つも走らなくなる。**この性質は失うには惜しい。

```
Packages/SplitKanaKit/                Foundation のみ。AzooKey を入れない
  Sources/SplitKanaCore/Conversion/
    KanaKanjiConverting.swift         抽象（既存）
    ConversionSession.swift           状態（新規）
    ConversionController.swift        状態機械（新規）
  Sources/SplitKanaUI/
    CandidateBarView.swift            候補表示（新規）
Keyboard/
  AzooKeyConverter.swift              KanaKanjiConverting の実装（新規）
```

抽象は Core、実装は拡張側。SPEC 5.3 が protocol だけ先に切っていたのはこのため。

## 2. 状態

```swift
public struct ConversionSession: Equatable, Sendable {
    public private(set) var reading: String       // 未確定の読み
    public private(set) var candidates: [String]
    public private(set) var selection: Int

    public var isComposing: Bool { !reading.isEmpty }
    public var selected: String?                  // candidates[selection]
}
```

`selection` は `candidates` の範囲で巡回する。

**変換器が候補を1つも返さなかったときは、読みそのものを唯一の候補として入れる。**
こうすると `isComposing` が真の間 `candidates` は必ず1つ以上あり、`selected` は非 nil になる。
確定時に「候補が無い」場合分けを持たなくて済む。

## 3. 効果

状態機械は `UITextDocumentProxy` を知らない（SPEC 1 の境界）。何をすべきかだけ返す。

```swift
public enum ConversionEffect: Equatable, Sendable {
    case markedText(String)      // 未確定表示を更新
    case commit(String)          // 確定して挿入
    case clear                   // 未確定を消す
    case passthrough(KeyOutput)  // 変換に関係ない出力はそのまま流す
}
```

拡張側の対応：

| 効果 | proxy 呼び出し |
|---|---|
| `.markedText(s)` | `setMarkedText(s, selectedRange: NSRange(location: s.count, length: 0))` |
| `.commit(s)` | `unmarkText()` → `insertText(s)` |
| `.clear` | `unmarkText()` |
| `.passthrough(o)` | 既存の `handle(_:)` にそのまま流す |

**効果は配列で返す。**「確定してからカーソル移動」のように2つ以上出る場合があるため。

## 4. 状態機械の規則

```swift
public struct ConversionController {
    public init(converter: any KanaKanjiConverting)
    public private(set) var session: ConversionSession
    public mutating func handle(_ output: KeyOutput) -> [ConversionEffect]
}
```

| 入力 | 変換中でない | 変換中 |
|---|---|---|
| `.insert(かな)` | 読みに追加 → `.markedText` | 同左 |
| `.space` | `.passthrough(.space)` | 次候補 → `.markedText` |
| `.candidate(-1)` | 何もしない | 前候補 → `.markedText` |
| `.newline` | `.passthrough(.newline)` | `.commit(選択中)` |
| `.backspace` | `.passthrough(.backspace)` | 読みを1文字削る。空になったら `.clear` |
| `.dakuten` | `.passthrough(.dakuten)` | 読みの末尾を巡回 → `.markedText` |
| `.cursor(n)` | `.passthrough` | `.commit` してから `.passthrough` |
| `.nextInputMode` | `.passthrough` | `.commit` してから `.passthrough` |
| `.custom` | `.passthrough` | `.passthrough`（確定しない） |

**読みが変わる操作**（かな追加・⌫・小゛゜）のたびに `converter.candidates(for:)` を
引き直し、`selection` を 0 に戻す。候補送りでは引き直さない。

`.custom` で確定しないのは、⚙（設定パネル）が `.custom("settings")` だから。
変換中に設定を開いても未確定の読みは残る。

**挙動の変化**：いまは打ったかながそのまま入るが、変換後は
**改行を押すまで未確定（下線付き）**になる。IME として正しいが体感は変わる。

## 5. 逆送り

SPEC 5.2 は「逆送りは空白キーの左フリック」と決めている。
`KeyKind.space` は現在フリックを持たないので、次を足す。

- `KeyOutput` に `case candidate(Int)` を追加
- 空白キーの左フリックが `.candidate(-1)` を出す

**ポップアップはかなキーだけに出すまま変えない**（`flickSet != nil` の条件は据え置き）。
空白キーのフリックは見た目に出さない。

## 6. 候補表示

`CandidateBarView`（SplitKanaUI）を `freeRegion` に置く。

- 横一列。選択中を強調
- **表示専用**。`allowsHitTesting(false)`（SPEC 5.2「候補はタップさせない」）
- **入りきらない分は切る。**選択中が常に見えるよう、選択中を中央付近に置いて
  前後を切り落とす。スクロールもタップもさせない
- 設定パネルとは排他。⚙ を開いている間は出さない

iPhone 縦（統合レイアウト）は中央の空きが無いので、キーボード上端に1行だけ出す。
iPad 優先の方針につき、ここは最小限にとどめる。

## 7. 変換器の生成

```swift
struct AzooKeyConverter: KanaKanjiConverting {
    func candidates(for reading: String) -> [String]
}
```

- **生成は重いので `viewDidLoad` でやらない**（SPEC 10）。最初のかな入力時に遅延生成する
- 辞書は `KanaKanjiConverterModuleWithDefaultDictionary` の同梱辞書を使う
- `Zenzai` トレイトは**オフ**。llama.cpp をリンクしない

## 8. テスト

状態機械は Core にあるので **Windows でも走る。**

- 候補送りが巡回すること（末尾の次は先頭）
- 逆送りが巡回すること
- 改行で確定し、セッションが空になること
- ⌫ で読みが1文字ずつ縮み、空になったら `.clear` が出ること
- 変換中でないときは全部 `.passthrough` になること
- カーソル移動・🌐 が「確定してから」の2効果を返すこと
- 読みが変わったら候補を引き直し、`selection` が 0 に戻ること

**AzooKey 自体はテストしない**（外部依存）。フェイクの `KanaKanjiConverting` で回す。

## 9. リスク

| | 内容 | 対応 |
|---|---|---|
| メモリ | 辞書 39MB が appex に載る。拡張の制限は厳しい（SPEC 4） | AzooKey は実際のキーボード拡張で動いている実績がある。実機で確認する |
| ビルド時間 | llama.cpp のバイナリ 239MB が初回に落ちる | `Zenzai` オフでリンクはされない。ダウンロードはキャッシュされる |
| 体感 | 変換が遅いと打鍵が止まる（SPEC 0 の最優先事項） | 実機で測る。遅ければ候補数を絞る |
| Windows | Core に AzooKey が漏れるとテストが全部止まる | 依存は `project.yml` にだけ書く。`Package.swift` は触らない |

## 10. 決めていないこと

- 学習（変換結果の記憶）を入れるか。まずは入れない
- 候補を何件出すか。実機で決める
- 変換が実用に足りなかった場合の撤退基準
