import XCTest
@testable import SplitKanaCore

final class KanaTextBufferTests: XCTestCase {

    func testInsertAndBackspace() {
        var buffer = KanaTextBuffer()
        buffer.apply(.insert("か"))
        buffer.apply(.insert("き"))
        XCTAssertEqual(buffer.text, "かき")
        buffer.apply(.backspace)
        XCTAssertEqual(buffer.text, "か")
        XCTAssertEqual(buffer.cursor, 1)
    }

    func testBackspaceAtStartIsSafe() {
        var buffer = KanaTextBuffer()
        buffer.apply(.backspace)
        XCTAssertEqual(buffer.text, "")
        XCTAssertEqual(buffer.cursor, 0)
    }

    func testDakutenCyclesCharacterBeforeCursor() {
        var buffer = KanaTextBuffer()
        buffer.apply(.insert("つ"))
        buffer.apply(.dakuten)
        XCTAssertEqual(buffer.text, "っ")
        buffer.apply(.dakuten)
        XCTAssertEqual(buffer.text, "づ")
        buffer.apply(.dakuten)
        XCTAssertEqual(buffer.text, "つ")
    }

    func testDakutenOnInertCharacterDoesNothing() {
        var buffer = KanaTextBuffer()
        buffer.apply(.insert("な"))
        XCTAssertFalse(buffer.apply(.dakuten))
        XCTAssertEqual(buffer.text, "な")
    }

    func testCursorMovementAndMidTextEditing() {
        var buffer = KanaTextBuffer()
        buffer.apply(.insert("あいう"))
        buffer.apply(.cursor(-1))
        XCTAssertEqual(buffer.cursor, 2)
        XCTAssertEqual(buffer.contextBeforeCursor, "あい")
        XCTAssertEqual(buffer.contextAfterCursor, "う")
        buffer.apply(.insert("ん"))
        XCTAssertEqual(buffer.text, "あいんう")
        buffer.apply(.backspace)
        XCTAssertEqual(buffer.text, "あいう")
    }

    func testDakutenAppliesAtCursorNotAtEnd() {
        var buffer = KanaTextBuffer()
        buffer.apply(.insert("かき"))
        buffer.apply(.cursor(-1))
        buffer.apply(.dakuten)
        XCTAssertEqual(buffer.text, "がき")
    }

    func testCursorIsClamped() {
        var buffer = KanaTextBuffer()
        buffer.apply(.insert("あ"))
        buffer.apply(.cursor(-10))
        XCTAssertEqual(buffer.cursor, 0)
        buffer.apply(.cursor(10))
        XCTAssertEqual(buffer.cursor, 1)
    }

    func testCustomOutputIsPassedThrough() {
        var buffer = KanaTextBuffer()
        XCTAssertFalse(buffer.apply(.custom("connect")))
        XCTAssertFalse(buffer.apply(.nextInputMode))
        XCTAssertEqual(buffer.text, "")
    }

    func testSpaceInsertsIdeographicSpace() {
        var buffer = KanaTextBuffer()
        buffer.apply(.space)
        XCTAssertEqual(buffer.text, "\u{3000}")
    }
}
