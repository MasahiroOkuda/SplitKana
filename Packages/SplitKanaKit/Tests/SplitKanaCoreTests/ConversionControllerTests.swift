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

    func testCandidateWhenNotComposingDoesNothing() {
        var c = controller()
        XCTAssertEqual(c.handle(.candidate(-1)), [])
    }
}
