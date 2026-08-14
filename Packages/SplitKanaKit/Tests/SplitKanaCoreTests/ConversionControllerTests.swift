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
