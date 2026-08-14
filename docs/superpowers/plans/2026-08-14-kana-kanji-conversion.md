# かな漢字変換 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** キーボード拡張でかな漢字変換を使えるようにする。空白キーで候補を送り、改行で確定する。

**Architecture:** 変換の状態機械は `SplitKanaCore` に置き、`UITextDocumentProxy` を知らない純ロジックとして保つ。状態機械は「何をすべきか」を `ConversionEffect` の配列で返し、拡張側がそれを proxy 呼び出しに落とす。変換エンジン（AzooKey）への依存は `Keyboard/` ターゲットだけに閉じ込め、`Packages/SplitKanaKit` は Foundation のみのまま保つ。

**Tech Stack:** Swift 5.9 / SwiftUI / UIKit / AzooKeyKanaKanjiConverter 0.9.0

**Spec:** `docs/superpowers/specs/2026-08-14-kana-kanji-conversion-design.md`

## Global Constraints

- `Packages/SplitKanaKit/Package.swift` に **AzooKey を足してはいけない**。足すと Windows での依存解決が失敗し、テストが1件も走らなくなる。依存は `project.yml` の `SplitKanaKeyboard` ターゲットにだけ書く
- `SplitKanaCore` は `Foundation` と `CoreGraphics` のみに依存する。SwiftUI / UIKit / `UITextDocumentProxy` を入れない
- テストの実行コマンドは **`swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0`**。素の `swift test` はこの Mac では `SplitKanaUI` の macOS availability エラーで落ちる（本件と無関係の既存問題）
- 作業ディレクトリは `/Users/shumasui/Documents/study/SplitKana`
- パッケージのテストは `Packages/SplitKanaKit` で実行する
- `xcodegen generate` はファイルを新規追加したあとに必ず実行する。ソースは glob 収集のため、実行しないと新ファイルがターゲットに入らない
- iOS ビルド確認は `xcodebuild -project SplitKana.xcodeproj -scheme SplitKanaHost -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=18.3.1' build`
- 学習機能は入れない（`LearningType.nothing`）

---

## File Structure

| ファイル | 責務 |
|---|---|
| `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionSession.swift` | 未確定の読みと候補の状態。値型 |
| `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionEffect.swift` | 状態機械が返す指示 |
| `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionController.swift` | 状態機械本体。`KeyOutput` を受けて効果を返す |
| `Packages/SplitKanaKit/Sources/SplitKanaCore/Input/KeyOutput.swift` | `case candidate(Int)` を追加（修正） |
| `Packages/SplitKanaKit/Sources/SplitKanaCore/Layout/KeyDescriptor.swift` | `KeyKind.output(for:)` を追加（修正） |
| `Packages/SplitKanaKit/Sources/SplitKanaUI/SplitKanaKeyboardView.swift` | `emit` を `output(for:)` 経由に（修正） |
| `Packages/SplitKanaKit/Sources/SplitKanaUI/CandidateBarView.swift` | 候補の表示。表示専用 |
| `Keyboard/AzooKeyConverter.swift` | `KanaKanjiConverting` の実装。AzooKey への依存はここだけ |
| `Keyboard/KeyboardViewController.swift` | 効果を proxy に落とす（修正） |
| `Keyboard/KeyboardRootView.swift` | 候補バーを差し込む（修正） |

---

### Task 1: ConversionSession と ConversionEffect

**Files:**
- Create: `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionSession.swift`
- Create: `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionEffect.swift`
- Test: `Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionSessionTests.swift`

**Interfaces:**
- Consumes: `KeyOutput`（既存）
- Produces: `ConversionSession`（`reading`, `candidates`, `selection`, `isComposing`, `selected`）、`ConversionEffect`（`.markedText`, `.commit`, `.clear`, `.passthrough`）

- [ ] **Step 1: Write the failing test**

`Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionSessionTests.swift`:

```swift
import XCTest
@testable import SplitKanaCore

final class ConversionSessionTests: XCTestCase {

    func testEmptySessionIsNotComposing() {
        let session = ConversionSession()
        XCTAssertFalse(session.isComposing)
        XCTAssertNil(session.selected)
        XCTAssertTrue(session.candidates.isEmpty)
    }

    func testComposingSessionExposesTheSelectedCandidate() {
        let session = ConversionSession(reading: "かん", candidates: ["感", "缶"], selection: 1)
        XCTAssertTrue(session.isComposing)
        XCTAssertEqual(session.selected, "缶")
    }

    /// 候補が空でも、読みがあるなら選択は決まっていなければならない。
    /// 確定時に「候補が無い」場合分けを持たなくて済ませるため。
    func testSelectedFallsBackToTheReadingWhenThereAreNoCandidates() {
        let session = ConversionSession(reading: "かん", candidates: [], selection: 0)
        XCTAssertEqual(session.selected, "かん")
    }

    func testSelectionOutOfRangeFallsBackToTheReading() {
        let session = ConversionSession(reading: "かん", candidates: ["感"], selection: 5)
        XCTAssertEqual(session.selected, "かん")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0 --filter ConversionSessionTests`
Expected: FAIL — `cannot find 'ConversionSession' in scope`

- [ ] **Step 3: Write minimal implementation**

`ConversionSession.swift`:

```swift
import Foundation

/// 未確定の読みと、その変換候補（SPEC 5.2）。
///
/// **proxy もアプリのモデルも知らない。**状態を持つだけ。
public struct ConversionSession: Equatable, Sendable {

    /// 未確定の読み。空なら変換中でない。
    public var reading: String
    public var candidates: [String]
    public var selection: Int

    public init(reading: String = "", candidates: [String] = [], selection: Int = 0) {
        self.reading = reading
        self.candidates = candidates
        self.selection = selection
    }

    public var isComposing: Bool { !reading.isEmpty }

    /// いま確定するならこの文字列。
    ///
    /// 候補が無い／範囲外なら読みそのものを返す。**変換中は必ず非 nil。**
    public var selected: String? {
        guard isComposing else { return nil }
        guard candidates.indices.contains(selection) else { return reading }
        return candidates[selection]
    }

    public static let empty = ConversionSession()
}
```

`ConversionEffect.swift`:

```swift
import Foundation

/// 状態機械が「何をすべきか」を返すための指示（SPEC 1 の境界）。
///
/// `SplitKanaCore` は `UITextDocumentProxy` に触らない。
/// 拡張側がこれを `setMarkedText` / `insertText` / `unmarkText` に落とす。
public enum ConversionEffect: Equatable, Sendable {
    /// 未確定表示を更新する
    case markedText(String)
    /// 確定して挿入する
    case commit(String)
    /// 未確定表示を消す
    case clear
    /// 変換に関係ない出力。そのまま流す
    case passthrough(KeyOutput)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0 --filter ConversionSessionTests`
Expected: PASS（4件）

- [ ] **Step 5: Commit**

```bash
git add Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionSession.swift \
        Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionEffect.swift \
        Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionSessionTests.swift
git commit -m "変換の状態と効果の型を追加"
```

---

### Task 2: ConversionController — かな入力と ⌫

**Files:**
- Create: `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionController.swift`
- Test: `Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionControllerTests.swift`

**Interfaces:**
- Consumes: `ConversionSession`, `ConversionEffect`, `KanaKanjiConverting`, `KeyOutput`
- Produces: `ConversionController(converter:)`、`var session: ConversionSession`、`mutating func handle(_ output: KeyOutput) -> [ConversionEffect]`

- [ ] **Step 1: Write the failing test**

`Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionControllerTests.swift`:

```swift
import XCTest
@testable import SplitKanaCore

/// 決め打ちの変換器。読みごとに返す候補を固定しておく。
struct FakeConverter: KanaKanjiConverting {
    var table: [String: [String]] = [:]
    func candidates(for reading: String) -> [String] {
        table[reading] ?? []
    }
}

final class ConversionControllerTests: XCTestCase {

    private func controller(
        _ table: [String: [String]] = ["か": ["下", "課"], "かん": ["感", "缶", "巻"]]
    ) -> ConversionController {
        ConversionController(converter: FakeConverter(table: table))
    }

    func testKanaBuildsTheReadingAndShowsMarkedText() {
        var c = controller()
        let effects = c.handle(.insert("か"))
        XCTAssertEqual(c.session.reading, "か")
        XCTAssertEqual(c.session.candidates, ["下", "課"])
        XCTAssertEqual(c.session.selection, 0)
        XCTAssertEqual(effects, [.markedText("下")])
    }

    func testEachKanaRefreshesCandidatesAndResetsSelection() {
        var c = controller()
        _ = c.handle(.insert("か"))
        c.session.selection = 1
        let effects = c.handle(.insert("ん"))
        XCTAssertEqual(c.session.reading, "かん")
        XCTAssertEqual(c.session.candidates, ["感", "缶", "巻"])
        XCTAssertEqual(c.session.selection, 0, "読みが変わったら選択は先頭に戻る")
        XCTAssertEqual(effects, [.markedText("感")])
    }

    func testMarkedTextFallsBackToTheReadingWhenThereIsNoCandidate() {
        var c = controller([:])
        let effects = c.handle(.insert("ぬ"))
        XCTAssertEqual(effects, [.markedText("ぬ")])
    }

    func testBackspaceShrinksTheReading() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let effects = c.handle(.backspace)
        XCTAssertEqual(c.session.reading, "か")
        XCTAssertEqual(effects, [.markedText("下")])
    }

    func testBackspaceOnTheLastCharacterClearsTheSession() {
        var c = controller()
        _ = c.handle(.insert("か"))
        let effects = c.handle(.backspace)
        XCTAssertFalse(c.session.isComposing)
        XCTAssertEqual(effects, [.clear])
    }

    func testBackspaceWhenNotComposingPassesThrough() {
        var c = controller()
        XCTAssertEqual(c.handle(.backspace), [.passthrough(.backspace)])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0 --filter ConversionControllerTests`
Expected: FAIL — `cannot find 'ConversionController' in scope`

- [ ] **Step 3: Write minimal implementation**

`ConversionController.swift`:

```swift
import Foundation

/// 変換の状態機械（SPEC 5.2）。
///
/// **`KeyOutput` を受けて `ConversionEffect` を返すだけ。**
/// テキストがどこへ行くかは知らない。だから Windows でもテストできる。
public struct ConversionController {

    private let converter: any KanaKanjiConverting
    public var session: ConversionSession

    public init(converter: any KanaKanjiConverting, session: ConversionSession = .empty) {
        self.converter = converter
        self.session = session
    }

    public mutating func handle(_ output: KeyOutput) -> [ConversionEffect] {
        switch output {
        case .insert(let text):
            session.reading += text
            return [refreshCandidates()]

        case .backspace where session.isComposing:
            session.reading.removeLast()
            guard session.isComposing else {
                session = .empty
                return [.clear]
            }
            return [refreshCandidates()]

        default:
            return [.passthrough(output)]
        }
    }

    /// 読みが変わったので候補を引き直す。選択は先頭に戻す。
    private mutating func refreshCandidates() -> ConversionEffect {
        session.candidates = converter.candidates(for: session.reading)
        session.selection = 0
        return .markedText(session.selected ?? session.reading)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0 --filter ConversionControllerTests`
Expected: PASS（6件）

- [ ] **Step 5: Commit**

```bash
git add Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionController.swift \
        Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionControllerTests.swift
git commit -m "変換の状態機械：かな入力と削除"
```

---

### Task 3: 候補送りと逆送り

**Files:**
- Modify: `Packages/SplitKanaKit/Sources/SplitKanaCore/Input/KeyOutput.swift`
- Modify: `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionController.swift`
- Modify: `Packages/SplitKanaKit/Sources/SplitKanaCore/Input/KanaTextBuffer.swift`
- Test: `Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionControllerTests.swift`

**Interfaces:**
- Consumes: Task 2 の `ConversionController.handle(_:)`
- Produces: `KeyOutput.candidate(Int)`（正で次候補、負で前候補）

- [ ] **Step 1: Write the failing test**

`ConversionControllerTests.swift` の `final class` の閉じ括弧の直前に足す:

```swift
    func testSpaceMovesToTheNextCandidate() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let effects = c.handle(.space)
        XCTAssertEqual(c.session.selection, 1)
        XCTAssertEqual(effects, [.markedText("缶")])
    }

    func testCandidateSelectionWrapsAround() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.handle(.space)      // 缶
        _ = c.handle(.space)      // 巻
        let effects = c.handle(.space)
        XCTAssertEqual(c.session.selection, 0, "末尾の次は先頭に戻る")
        XCTAssertEqual(effects, [.markedText("感")])
    }

    func testBackwardCandidateWrapsAround() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let effects = c.handle(.candidate(-1))
        XCTAssertEqual(c.session.selection, 2, "先頭の前は末尾へ回る")
        XCTAssertEqual(effects, [.markedText("巻")])
    }

    func testCandidateMovementDoesNotRequeryTheConverter() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let before = c.session.candidates
        _ = c.handle(.space)
        XCTAssertEqual(c.session.candidates, before, "候補送りで引き直してはいけない")
    }

    func testSpaceWhenNotComposingPassesThrough() {
        var c = controller()
        XCTAssertEqual(c.handle(.space), [.passthrough(.space)])
    }

    func testCandidateWhenNotComposingDoesNothing() {
        var c = controller()
        XCTAssertEqual(c.handle(.candidate(-1)), [])
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0 --filter ConversionControllerTests`
Expected: FAIL — `type 'KeyOutput' has no member 'candidate'`

- [ ] **Step 3: Write minimal implementation**

`KeyOutput.swift` の `case cursor(Int)` の直後に足す:

```swift
    /// 変換候補を送る。+1 で次、-1 で前（SPEC 5.2）
    case candidate(Int)
```

`KanaTextBuffer.swift` の `apply(_:)` の `switch` に足す（網羅性のため。バッファは変換を扱わない）:

```swift
        case .candidate:
            return false
```

`ConversionController.handle(_:)` の `case .backspace where ...` と `default:` の間に足す:

```swift
        case .space where session.isComposing:
            return [moveCandidate(by: 1)]

        case .candidate(let step):
            guard session.isComposing else { return [] }
            return [moveCandidate(by: step)]
```

同ファイルの `refreshCandidates()` の下に足す:

```swift
    /// 候補を送る。**引き直さない。**端は巡回する。
    private mutating func moveCandidate(by step: Int) -> ConversionEffect {
        let count = session.candidates.count
        guard count > 0 else { return .markedText(session.reading) }
        session.selection = ((session.selection + step) % count + count) % count
        return .markedText(session.selected ?? session.reading)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0`
Expected: PASS（既存51件 + 新規もすべて）

- [ ] **Step 5: Commit**

```bash
git add -A Packages/SplitKanaKit
git commit -m "変換の状態機械：候補送りと逆送り"
```

---

### Task 4: 確定と passthrough

**Files:**
- Modify: `Packages/SplitKanaKit/Sources/SplitKanaCore/Conversion/ConversionController.swift`
- Test: `Packages/SplitKanaKit/Tests/SplitKanaCoreTests/ConversionControllerTests.swift`

**Interfaces:**
- Consumes: Task 3 までの `ConversionController`
- Produces: 確定の規則（改行で `.commit`、カーソル移動と 🌐 は `.commit` してから `.passthrough`）

- [ ] **Step 1: Write the failing test**

`ConversionControllerTests.swift` に足す:

```swift
    func testNewlineCommitsTheSelectedCandidate() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.handle(.space)                     // 缶
        let effects = c.handle(.newline)
        XCTAssertEqual(effects, [.commit("缶")])
        XCTAssertFalse(c.session.isComposing, "確定したらセッションは空になる")
        XCTAssertTrue(c.session.candidates.isEmpty)
    }

    func testNewlineWhenNotComposingPassesThrough() {
        var c = controller()
        XCTAssertEqual(c.handle(.newline), [.passthrough(.newline)])
    }

    func testCursorCommitsFirstThenPassesThrough() {
        var c = controller()
        _ = c.handle(.insert("か"))
        let effects = c.handle(.cursor(-1))
        XCTAssertEqual(effects, [.commit("下"), .passthrough(.cursor(-1))])
        XCTAssertFalse(c.session.isComposing)
    }

    func testNextInputModeCommitsFirstThenPassesThrough() {
        var c = controller()
        _ = c.handle(.insert("か"))
        let effects = c.handle(.nextInputMode)
        XCTAssertEqual(effects, [.commit("下"), .passthrough(.nextInputMode)])
    }

    /// ⚙ は `.custom("settings")`。設定を開いても未確定の読みは残す。
    func testCustomDoesNotCommit() {
        var c = controller()
        _ = c.handle(.insert("か"))
        let effects = c.handle(.custom("settings"))
        XCTAssertEqual(effects, [.passthrough(.custom("settings"))])
        XCTAssertTrue(c.session.isComposing, "設定を開いても読みは消えない")
    }

    func testDakutenCyclesTheLastCharacterOfTheReading() {
        var c = controller(["かん": ["感"], "がん": ["岸", "眼"]])
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.handle(.backspace)                 // 「か」に戻す
        let effects = c.handle(.dakuten)
        XCTAssertEqual(c.session.reading, "が")
        XCTAssertEqual(effects, [.markedText("が")], "候補が無いので読みがそのまま出る")
    }

    func testDakutenWhenNotComposingPassesThrough() {
        var c = controller()
        XCTAssertEqual(c.handle(.dakuten), [.passthrough(.dakuten)])
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0 --filter ConversionControllerTests`
Expected: FAIL — `testNewlineCommitsTheSelectedCandidate` が `[.passthrough(.newline)]` を返して落ちる

- [ ] **Step 3: Write minimal implementation**

`ConversionController.handle(_:)` の `default:` の直前に足す:

```swift
        case .newline where session.isComposing:
            return [commit()]

        case .dakuten where session.isComposing:
            guard let last = session.reading.last,
                  let cycled = DakutenCycle.next(after: last) else {
                return []
            }
            session.reading.removeLast()
            session.reading.append(cycled)
            return [refreshCandidates()]

        case .cursor, .nextInputMode:
            guard session.isComposing else { return [.passthrough(output)] }
            return [commit(), .passthrough(output)]
```

同ファイルの `moveCandidate(by:)` の下に足す:

```swift
    /// 選択中の候補で確定し、セッションを空に戻す。
    private mutating func commit() -> ConversionEffect {
        let text = session.selected ?? session.reading
        session = .empty
        return .commit(text)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0`
Expected: PASS（全件）

- [ ] **Step 5: Commit**

```bash
git add -A Packages/SplitKanaKit
git commit -m "変換の状態機械：確定と受け流し"
```

---

### Task 5: 空白キーの左フリックで逆送り

**Files:**
- Modify: `Packages/SplitKanaKit/Sources/SplitKanaCore/Layout/KeyDescriptor.swift`
- Modify: `Packages/SplitKanaKit/Sources/SplitKanaUI/SplitKanaKeyboardView.swift`
- Test: `Packages/SplitKanaKit/Tests/SplitKanaCoreTests/KeyDescriptorTests.swift`

**Interfaces:**
- Consumes: `KeyOutput.candidate(Int)`（Task 3）
- Produces: `KeyKind.output(for direction: FlickDirection) -> KeyOutput`

- [ ] **Step 1: Write the failing test**

`Packages/SplitKanaKit/Tests/SplitKanaCoreTests/KeyDescriptorTests.swift`（新規）:

```swift
import XCTest
@testable import SplitKanaCore

final class KeyDescriptorTests: XCTestCase {

    func testSpaceLeftFlickAsksForThePreviousCandidate() {
        XCTAssertEqual(KeyKind.space.output(for: .left), .candidate(-1))
    }

    func testSpaceInAnyOtherDirectionIsStillASpace() {
        for direction in [FlickDirection.center, .up, .right, .down] {
            XCTAssertEqual(KeyKind.space.output(for: direction), .space,
                           "\(direction) では空白のまま")
        }
    }

    func testKanaUsesItsFlickSet() {
        let set = FlickSet(center: "か", left: "き", up: "く", right: "け", down: "こ")
        XCTAssertEqual(KeyKind.kana(set).output(for: .up), .insert("く"))
        XCTAssertEqual(KeyKind.kana(set).output(for: .center), .insert("か"))
    }

    /// 空白以外の機能キーは方向を無視する。
    func testOtherKeysIgnoreDirection() {
        XCTAssertEqual(KeyKind.backspace.output(for: .left), .backspace)
        XCTAssertEqual(KeyKind.newline.output(for: .left), .newline)
        XCTAssertEqual(KeyKind.dakuten.output(for: .left), .dakuten)
    }

    /// ポップアップはかなキーだけ。空白にフリックを足しても出さない。
    func testSpaceHasNoPopup() {
        XCTAssertNil(KeyKind.space.flickSet)
    }
}
```

`FlickSet` の初期化子が上と違う場合は `FlickTable.swift` を読んで実際の形に合わせること。

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0 --filter KeyDescriptorTests`
Expected: FAIL — `value of type 'KeyKind' has no member 'output'`

- [ ] **Step 3: Write minimal implementation**

`KeyDescriptor.swift` の `KeyKind` の `flickSet` の下に足す:

```swift
    /// フリック方向を踏まえた出力。
    ///
    /// 空白キーだけは左フリックで候補の逆送りになる（SPEC 5.2）。
    /// **ポップアップは出さない。**見た目に出るのはかなキーのフリックだけ。
    public func output(for direction: FlickDirection) -> KeyOutput {
        switch self {
        case .kana(let set):
            return .insert(set.character(for: direction))
        case .space:
            return direction == .left ? .candidate(-1) : .space
        default:
            return baseOutput
        }
    }
```

`SplitKanaKeyboardView.swift` の `emit(_:)` を丸ごと差し替える:

```swift
    private func emit(_ finger: Finger) {
        onOutput(finger.hit.key.kind.output(for: finger.direction))
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0`
Expected: PASS（全件）

- [ ] **Step 5: Commit**

```bash
git add -A Packages/SplitKanaKit
git commit -m "空白キーの左フリックで候補を逆送り"
```

---

### Task 6: 候補バーの表示

**Files:**
- Create: `Packages/SplitKanaKit/Sources/SplitKanaUI/CandidateBarView.swift`

**Interfaces:**
- Consumes: `ConversionSession`（Task 1）
- Produces: `CandidateBarView(session:region:palette:)`

テストは書かない。SwiftUI の見た目であり、`SplitKanaUI` は Windows ではビルドされないため
（README「UI のコンパイルエラーは Windows では出ない」）。確認は実機で行う。

- [ ] **Step 1: 実装を書く**

`CandidateBarView.swift`:

```swift
#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore

/// 変換候補を並べて見せるだけのビュー（SPEC 5.2）。
///
/// **タップさせない。**中央は親指が届かないので、候補は空白キーで送る。
/// 入りきらない分は切る。選択中が必ず見えるよう、選択中を中央付近に置く。
public struct CandidateBarView: View {

    private let session: ConversionSession
    private let region: CGRect

    public init(session: ConversionSession, region: CGRect) {
        self.session = session
        self.region = region
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                Text(item.text)
                    .font(.system(size: 18))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(item.isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
                    )
                    .foregroundStyle(item.isSelected ? Color.primary : Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: region.width, height: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 1.0).opacity(0.92))
        )
        .offset(x: region.minX, y: region.minY)
        // 表示専用。タッチはキーボードのものを邪魔しない。
        .allowsHitTesting(false)
    }

    private struct Item {
        let text: String
        let isSelected: Bool
    }

    /// 選択中が必ず入るよう、その前後だけを取る。
    private var visible: [Item] {
        guard !session.candidates.isEmpty else {
            return session.isComposing ? [Item(text: session.reading, isSelected: true)] : []
        }
        let maximum = 8
        let count = session.candidates.count
        let start = max(0, min(session.selection - maximum / 2, count - maximum))
        let end = min(count, start + maximum)
        return (start..<end).map {
            Item(text: session.candidates[$0], isSelected: $0 == session.selection)
        }
    }
}
#endif
```

- [ ] **Step 2: ビルドが通ることを確認**

Run: `xcodegen generate && xcodebuild -project SplitKana.xcodeproj -scheme SplitKanaHost -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=18.3.1' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A Packages/SplitKanaKit SplitKana.xcodeproj
git commit -m "変換候補バーを追加"
```

---

### Task 7: AzooKey の導入とアダプタ

**Files:**
- Modify: `project.yml`
- Create: `Keyboard/AzooKeyConverter.swift`

**Interfaces:**
- Consumes: `KanaKanjiConverting`（既存）
- Produces: `AzooKeyConverter()`（`KanaKanjiConverting` 準拠）

- [ ] **Step 1: 依存を project.yml に足す**

`project.yml` の `packages:` に足す（`SplitKanaKit` の下）:

```yaml
  AzooKeyKanaKanjiConverter:
    url: https://github.com/ensan-hcl/AzooKeyKanaKanjiConverter
    exactVersion: 0.9.0
```

`targets.SplitKanaKeyboard.dependencies` に足す:

```yaml
      - package: AzooKeyKanaKanjiConverter
        product: KanaKanjiConverterModuleWithDefaultDictionary
```

**`Packages/SplitKanaKit/Package.swift` には絶対に足さない。**足すと Windows でテストが走らなくなる。

- [ ] **Step 2: 解決とビルドを確認**

Run: `xcodegen generate && xcodebuild -project SplitKana.xcodeproj -scheme SplitKanaHost -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=18.3.1' build`
Expected: `** BUILD SUCCEEDED **`。初回は llama.cpp のバイナリ（約239MB）をダウンロードするため**10分以上かかることがある**。`Zenzai` トレイトはオフなのでリンクはされない。

- [ ] **Step 3: アダプタを書く**

`Keyboard/AzooKeyConverter.swift`:

```swift
import Foundation
import SplitKanaCore
import KanaKanjiConverterModuleWithDefaultDictionary

/// AzooKey を `KanaKanjiConverting` に合わせるアダプタ。
///
/// **AzooKey への依存はこのファイルだけ。**`SplitKanaCore` からは見えない。
/// 変換器を差し替えたくなったら、ここを別の実装に取り替えるだけで済む（SPEC 5.3）。
@MainActor
final class AzooKeyConverter: KanaKanjiConverting {

    private let converter = KanaKanjiConverter()
    private let options: ConvertRequestOptions

    init() {
        // 学習は入れない。App Group を使わないので保存先は拡張自身の Library。
        let library = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        options = .withDefaultDictionary(
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: library,
            sharedContainerURL: library,
            metadata: .init(versionString: "SplitKana")
        )
    }

    nonisolated func candidates(for reading: String) -> [String] {
        MainActor.assumeIsolated {
            guard !reading.isEmpty else { return [] }
            var composing = ComposingText()
            composing.insertAtCursorPosition(reading, inputStyle: .direct)
            let result = converter.requestCandidates(composing, options: options)
            return result.mainResults.map(\.text)
        }
    }
}
```

`ConvertRequestOptions.withDefaultDictionary` の引数名が違ってビルドが落ちたら、
`.build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/KanaKanjiConverterModuleWithDefaultDictionary.swift`
を読んで実際の並びに合わせること。

- [ ] **Step 4: ビルドを確認**

Run: `xcodegen generate && xcodebuild -project SplitKana.xcodeproj -scheme SplitKanaHost -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=18.3.1' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A project.yml Keyboard SplitKana.xcodeproj
git commit -m "AzooKey を拡張ターゲットに導入"
```

---

### Task 8: 拡張に結線する

**Files:**
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `Keyboard/KeyboardRootView.swift`

**Interfaces:**
- Consumes: `ConversionController`（Task 4）、`AzooKeyConverter`（Task 7）、`CandidateBarView`（Task 6）
- Produces: 変換が効くキーボード

- [ ] **Step 1: KeyboardViewController に変換を挿す**

`KeyboardViewController` の `isShowingSettings` の下に足す:

```swift
    /// 変換の状態機械。**生成が重いので最初のかな入力まで作らない**（SPEC 10）。
    private var conversion: ConversionController?

    private var conversionSession: ConversionSession {
        conversion?.session ?? .empty
    }

    private func ensureConversion() -> ConversionController {
        if let conversion { return conversion }
        let created = ConversionController(converter: AzooKeyConverter())
        conversion = created
        return created
    }
```

`handle(_ output: KeyOutput)` を丸ごと差し替える。既存の中身は `apply(_:)` に移す:

```swift
    /// キーボードからの出力。まず変換に通し、出てきた効果を proxy に落とす。
    private func handle(_ output: KeyOutput) {
        var controller = ensureConversion()
        let effects = controller.handle(output)
        conversion = controller

        for effect in effects {
            switch effect {
            case .markedText(let text):
                textDocumentProxy.setMarkedText(
                    text, selectedRange: NSRange(location: text.utf16.count, length: 0))
            case .commit(let text):
                textDocumentProxy.unmarkText()
                textDocumentProxy.insertText(text)
            case .clear:
                textDocumentProxy.unmarkText()
            case .passthrough(let output):
                apply(output)
            }
        }

        // 候補の表示を更新する。
        refreshRootView()
    }
```

既存の `handle` の `switch output` の中身を、そのまま次の関数にする（`.insert` はもう
変換が受けるので通らないが、念のため残す）:

```swift
    /// 変換に関係ない出力を proxy に流す。
    private func apply(_ output: KeyOutput) {
        let proxy = textDocumentProxy
        switch output {
        case .insert(let text):
            proxy.insertText(text)
        case .backspace:
            proxy.deleteBackward()
        case .space:
            proxy.insertText(" ")
        case .newline:
            proxy.insertText("\n")
        case .dakuten:
            guard let before = proxy.documentContextBeforeInput,
                  let cycled = DakutenCycle.cyclingLastCharacter(of: before) else { return }
            proxy.deleteBackward()
            proxy.insertText(String(cycled))
        case .cursor(let offset):
            proxy.adjustTextPosition(byCharacterOffset: offset)
        case .candidate:
            break   // 変換中しか意味を持たない
        case .nextInputMode:
            advanceToNextInputMode()
        case KeyboardConfiguration.settingsOutput:
            isShowingSettings.toggle()
            reloadSettings()
        case .custom:
            break
        }
    }
```

`makeRootView` の下に足す:

```swift
    /// 候補表示だけを更新する。寸法は変わらないので作り直さない。
    private func refreshRootView() {
        guard let geometry = hosting?.rootView.geometry else { return }
        hosting?.rootView = makeRootView(
            geometry: geometry,
            configuration: KeyboardSettings.configuration(for: currentDeviceClass)
        )
    }
```

`makeRootView` の `KeyboardRootView(...)` 呼び出しに `session: conversionSession,` を足す。

- [ ] **Step 2: KeyboardRootView に候補バーを差す**

`KeyboardRootView` のプロパティに足す:

```swift
    let session: ConversionSession
```

`body` の `if isShowingSettings { ... }` の**前**に足す:

```swift
                // 設定パネルとは排他。⚙ を開いている間は候補を出さない。
                if session.isComposing, !isShowingSettings {
                    CandidateBarView(session: session, region: candidateRegion(for: geometry))
                }
```

`settingsRegion(for:)` の下に足す:

```swift
    /// 候補バーの置き場所。分割時は中央の空きの上寄り、統合時はキーボード上端。
    private func candidateRegion(for geometry: KeyboardGeometry) -> CGRect {
        let region = geometry.isSplit
            ? geometry.freeRegion
            : CGRect(origin: .zero, size: geometry.containerSize)
        return CGRect(x: region.minX + 6, y: region.minY + 6,
                      width: max(0, region.width - 12), height: 40)
    }
```

- [ ] **Step 3: ビルドを確認**

Run: `xcodegen generate && xcodebuild -project SplitKana.xcodeproj -scheme SplitKanaHost -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4),OS=18.3.1' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: パッケージのテストが壊れていないことを確認**

Run: `cd Packages/SplitKanaKit && swift test -Xswiftc -target -Xswiftc arm64-apple-macosx14.0`
Expected: PASS（全件）

- [ ] **Step 5: Commit**

```bash
git add -A Keyboard SplitKana.xcodeproj
git commit -m "拡張に変換を結線"
```

- [ ] **Step 6: 実機で確認する（人間の作業）**

⌘R →「分割かな」で確認する。

1. かなを打つと**下線付きの未確定文字**が出るか
2. **空白キーで候補が変わる**か
3. **改行で確定**するか
4. 空白キーの**左フリックで候補が戻る**か
5. ⌫ で読みが1文字ずつ縮むか
6. 変換していないときの空白・改行が今までどおりか
7. **変換の速度**。打鍵が止まる感じがないか（SPEC 0 の最優先事項）
8. **落ちないか。**拡張はメモリ制限が厳しい（SPEC 4）。辞書は 39MB ある

---

## Self-Review

**1. Spec coverage**

| 設計書の節 | 対応するタスク |
|---|---|
| 1. 依存の置き場所 | Task 7（`project.yml` にだけ書く。Global Constraints にも明記） |
| 2. 状態 | Task 1 |
| 3. 効果 | Task 1（型）、Task 8（proxy への対応表） |
| 4. 状態機械の規則 | Task 2（かな・⌫）、Task 3（候補送り）、Task 4（確定・受け流し） |
| 5. 逆送り | Task 3（`KeyOutput.candidate`）、Task 5（空白の左フリック） |
| 6. 候補表示 | Task 6、Task 8（排他と置き場所） |
| 7. 変換器の生成 | Task 7（アダプタ）、Task 8（遅延生成） |
| 8. テスト | Task 1〜5 に分散。`FakeConverter` は Task 2 で定義 |

**2. Placeholder scan** — 「後で実装」「適切に処理」の類はなし。すべて実コードを記載。

**3. Type consistency**

- `ConversionSession(reading:candidates:selection:)` — Task 1 で定義、Task 2〜4 で使用。一致
- `ConversionController(converter:session:)` — Task 2 で定義、`session` は既定引数付き。テストは `init(converter:)` で呼ぶ。一致
- `ConversionEffect` の4ケース — Task 1 で定義、Task 8 の `switch` が網羅。一致
- `KeyOutput.candidate(Int)` — Task 3 で追加、Task 5 の `output(for:)` と Task 8 の `apply` が使用。一致
- `KeyKind.output(for:)` — Task 5 で定義、同 Task の `emit` が使用。一致
- `CandidateBarView(session:region:)` — Task 6 で定義、Task 8 が使用。一致

**注意点**：Task 8 の `refreshRootView()` は `hosting?.rootView.geometry` を読む。
`KeyboardRootView.geometry` は `let` なので読める。
