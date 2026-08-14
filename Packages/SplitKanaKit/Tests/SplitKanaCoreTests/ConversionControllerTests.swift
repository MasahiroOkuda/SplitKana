import XCTest
@testable import SplitKanaCore

/// 決め打ちの変換器。読みごとに返す候補を固定しておく。
final class FakeConverter: KanaKanjiConverting {
    var table: [String: [String]] = [:]
    /// 候補引きの呼び出し回数。純粋な fake では引き直しと初回呼び出しを区別できないので、
    /// 明示的にカウントして検証する（テスト: testCandidateMovementDoesNotRequeryTheConverter）。
    private(set) var callCount = 0

    init(table: [String: [String]] = [:]) {
        self.table = table
    }

    func candidates(for reading: String) -> [String] {
        callCount += 1
        return table[reading] ?? []
    }
}

final class ConversionControllerTests: XCTestCase {

    private func controller(
        _ table: [String: [String]] = ["か": ["下", "課"], "かん": ["感", "缶", "巻"]]
    ) -> ConversionController {
        let converter = FakeConverter(table: table)
        return ConversionController(converter: converter)
    }

    func testKanaBuildsTheReadingAndShowsMarkedText() {
        var c = controller()
        let effects = c.handle(.insert("か"))
        XCTAssertEqual(c.session.reading, "か")
        XCTAssertEqual(c.session.candidates, ["か", "下", "課"],
                       "第1候補は必ず無変換の読み")
        XCTAssertEqual(c.session.selection, 0)
        XCTAssertEqual(effects, [.markedText("か")], "打っている間は漢字に化けない")
    }

    func testEachKanaRefreshesCandidatesAndResetsSelection() {
        var c = controller()
        _ = c.handle(.insert("か"))
        c.session.selection = 1
        let effects = c.handle(.insert("ん"))
        XCTAssertEqual(c.session.reading, "かん")
        XCTAssertEqual(c.session.candidates, ["かん", "感", "缶", "巻"])
        XCTAssertEqual(c.session.selection, 0, "読みが変わったら選択は先頭に戻る")
        XCTAssertEqual(effects, [.markedText("かん")])
    }

    // MARK: - 学習への通知

    /// 何を学習に渡したかを記録するだけの変換器。
    final class SpyConverter: KanaKanjiConverting {
        var table: [String: [String]] = [:]
        private(set) var learned: [(committed: String, reading: String)] = []
        private(set) var persistCount = 0

        init(table: [String: [String]]) { self.table = table }

        func candidates(for reading: String) -> [String] { table[reading] ?? [] }

        func learn(_ committed: String, for reading: String) {
            learned.append((committed, reading))
        }

        func persistLearning() { persistCount += 1 }
    }

    func testConfirmingWithTheEnterKeyNotifiesLearning() {
        let spy = SpyConverter(table: ["かん": ["感", "缶"]])
        var c = ConversionController(converter: spy)
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.handle(.space)                    // 感
        _ = c.handle(.newline)

        XCTAssertEqual(spy.learned.count, 1)
        XCTAssertEqual(spy.learned.first?.committed, "感")
        XCTAssertEqual(spy.learned.first?.reading, "かん", "読みも一緒に渡す")
    }

    /// **タップ確定でも同じように学習が走る。**経路が分かれていない証拠。
    func testConfirmingByTapNotifiesLearning() {
        let spy = SpyConverter(table: ["かん": ["感", "缶"]])
        var c = ConversionController(converter: spy)
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.commitCandidate(at: 2)            // ["かん", "感", "缶"] の 缶

        XCTAssertEqual(spy.learned.count, 1)
        XCTAssertEqual(spy.learned.first?.committed, "缶")
        XCTAssertEqual(spy.learned.first?.reading, "かん")
    }

    /// カーソル移動や 🌐 での暗黙の確定も学習に乗る。
    func testImplicitCommitNotifiesLearning() {
        let spy = SpyConverter(table: ["か": ["下"]])
        var c = ConversionController(converter: spy)
        _ = c.handle(.insert("か"))
        _ = c.handle(.cursor(-1))
        XCTAssertEqual(spy.learned.map(\.committed), ["か"])
    }

    /// 確定していないなら何も学習しない。
    func testNoLearningWithoutConfirmation() {
        let spy = SpyConverter(table: ["かん": ["感"]])
        var c = ConversionController(converter: spy)
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.handle(.space)
        _ = c.handle(.backspace)
        XCTAssertTrue(spy.learned.isEmpty)
    }

    func testPersistLearningIsForwarded() {
        let spy = SpyConverter(table: [:])
        let c = ConversionController(converter: spy)
        c.persistLearning()
        XCTAssertEqual(spy.persistCount, 1)
    }

    // MARK: - 候補のタップ確定

    /// タップは選択して止まるのではなく、その場で確定する。
    func testTappingACandidateCommitsItImmediately() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let effects = c.commitCandidate(at: 2)          // ["かん", "感", "缶", "巻"]
        XCTAssertEqual(effects, [.commit("缶")])
        XCTAssertFalse(c.session.isComposing, "確定したらセッションは空になる")
    }

    /// 無変換（先頭）もタップで確定できる。
    func testTappingTheUnconvertedReadingCommitsIt() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        XCTAssertEqual(c.commitCandidate(at: 0), [.commit("かん")])
    }

    /// **キーでの確定と同じ結果になること。**確定の経路が分かれていると、
    /// 学習や後処理を足したときに片方だけ漏れる。
    func testTapAndKeyConfirmationAgree() {
        var tapped = controller()
        _ = tapped.handle(.insert("か"))
        _ = tapped.handle(.insert("ん"))
        let byTap = tapped.commitCandidate(at: 1)

        var keyed = controller()
        _ = keyed.handle(.insert("か"))
        _ = keyed.handle(.insert("ん"))
        _ = keyed.handle(.space)                        // 選択を 1 へ
        let byKey = keyed.handle(.newline)

        XCTAssertEqual(byTap, byKey)
        XCTAssertEqual(tapped.session, keyed.session)
    }

    /// 表示と状態がずれた瞬間にタップが来ても壊れない。
    func testTappingOutOfRangeIsIgnored() {
        var c = controller()
        _ = c.handle(.insert("か"))
        XCTAssertEqual(c.commitCandidate(at: 99), [])
        XCTAssertTrue(c.session.isComposing, "無視するだけ。読みは残る")
    }

    func testTappingWhenNotComposingIsIgnored() {
        var c = controller()
        XCTAssertEqual(c.commitCandidate(at: 0), [])
    }

    // MARK: - 第1候補は必ず無変換

    /// **打っている最中に勝手に漢字へ化けない。**
    /// 変換したいときだけ空白キーで送る。
    func testFirstCandidateIsAlwaysTheUnconvertedReading() {
        var c = controller()
        for reading in ["か", "かん"] {
            var built = controller()
            for character in reading {
                _ = built.handle(.insert(String(character)))
            }
            XCTAssertEqual(built.session.candidates.first, reading,
                           "\(reading) の第1候補が無変換になっていない")
            XCTAssertEqual(built.session.selected, reading)
        }

        // 送れば変換候補に入り、一周すれば無変換に戻る。
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        XCTAssertEqual(c.session.selected, "かん")
        _ = c.handle(.space)
        XCTAssertEqual(c.session.selected, "感")
    }

    /// 変換器が読みと同じものを返しても、先頭に2つ並べない。
    func testTheReadingIsNotDuplicatedWhenTheConverterReturnsIt() {
        var c = controller(["か": ["か", "下"]])
        _ = c.handle(.insert("か"))
        XCTAssertEqual(c.session.candidates, ["か", "下"])
    }

    /// 確定せずに読みだけ伸ばしても、常に無変換が先頭に居続ける。
    func testTheReadingStaysFirstAsItGrows() {
        var c = controller(["か": ["下"], "かん": ["感"], "かんが": ["考"]])
        for (character, reading) in zip("かんが", ["か", "かん", "かんが"]) {
            _ = c.handle(.insert(String(character)))
            XCTAssertEqual(c.session.candidates.first, reading)
            XCTAssertEqual(c.session.selection, 0)
        }
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
        XCTAssertEqual(effects, [.markedText("か")])
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

    func testSpaceMovesToTheNextCandidate() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let effects = c.handle(.space)
        XCTAssertEqual(c.session.selection, 1)
        XCTAssertEqual(effects, [.markedText("感")], "1回送って初めて変換候補が出る")
    }

    func testCandidateSelectionWrapsAround() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.handle(.space)      // 感
        _ = c.handle(.space)      // 缶
        _ = c.handle(.space)      // 巻
        let effects = c.handle(.space)
        XCTAssertEqual(c.session.selection, 0, "末尾の次は先頭に戻る")
        XCTAssertEqual(effects, [.markedText("かん")], "一周したら無変換に戻る")
    }

    func testBackwardCandidateWrapsAround() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let effects = c.handle(.candidate(-1))
        XCTAssertEqual(c.session.selection, 3, "先頭の前は末尾へ回る")
        XCTAssertEqual(effects, [.markedText("巻")])
    }

    func testCandidateMovementDoesNotRequeryTheConverter() {
        let converter = FakeConverter(table: ["か": ["下", "課"], "かん": ["感", "缶", "巻"]])
        var c = ConversionController(converter: converter)
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        let callCountAfterBuilding = converter.callCount
        _ = c.handle(.space)
        let callCountAfterSpace = converter.callCount
        _ = c.handle(.candidate(-1))
        let callCountAfterCandidate = converter.callCount
        XCTAssertEqual(callCountAfterSpace, callCountAfterBuilding, "候補送りで引き直してはいけない")
        XCTAssertEqual(callCountAfterCandidate, callCountAfterBuilding, "逆送りでも引き直してはいけない")
    }

    func testSpaceWhenNotComposingPassesThrough() {
        var c = controller()
        XCTAssertEqual(c.handle(.space), [.passthrough(.space)])
    }

    /// 空白キーの左フリックは `.candidate(-1)`。変換中でなければ空白として通す。
    /// いちばん押されるキーで無音の取りこぼしが起きるほうが、
    /// 意図しない空白が1つ入るより体感が悪い（SPEC 0 の最優先＝入力が止まらないこと）。
    func testCandidateWhenNotComposingTypesASpace() {
        var c = controller()
        XCTAssertEqual(c.handle(.candidate(-1)), [.passthrough(.space)])
    }

    func testNewlineCommitsTheSelectedCandidate() {
        var c = controller()
        _ = c.handle(.insert("か"))
        _ = c.handle(.insert("ん"))
        _ = c.handle(.space)                     // 感
        let effects = c.handle(.newline)
        XCTAssertEqual(effects, [.commit("感")])
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
        XCTAssertEqual(effects, [.commit("か"), .passthrough(.cursor(-1))])
        XCTAssertFalse(c.session.isComposing)
    }

    func testNextInputModeCommitsFirstThenPassesThrough() {
        var c = controller()
        _ = c.handle(.insert("か"))
        let effects = c.handle(.nextInputMode)
        XCTAssertEqual(effects, [.commit("か"), .passthrough(.nextInputMode)])
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
}
