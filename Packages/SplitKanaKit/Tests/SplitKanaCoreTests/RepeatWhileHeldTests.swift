import XCTest
import Foundation
@testable import SplitKanaCore

/// 押しっぱなしで繰り返すもの（SPEC 2.5）。
final class RepeatWhileHeldTests: XCTestCase {

    func testDeleteAndCursorRepeat() {
        XCTAssertTrue(KeyOutput.backspace.repeatsWhileHeld)
        XCTAssertTrue(KeyOutput.cursor(-1).repeatsWhileHeld)
        XCTAssertTrue(KeyOutput.cursor(1).repeatsWhileHeld)
    }

    /// 押しっぱなしで同じ字が並ぶのは事故にしかならない。
    func testTextInputDoesNotRepeat() {
        for output: KeyOutput in [.insert("あ"), .space, .newline, .dakuten] {
            XCTAssertFalse(output.repeatsWhileHeld, "\(output) が繰り返しになっている")
        }
    }

    /// 候補送りも繰り返さない。行き過ぎたぶんを戻す操作が増えるだけ。
    func testCandidateAndModeKeysDoNotRepeat() {
        for output: KeyOutput in [.candidate(1), .candidate(-1), .nextInputMode,
                                  KeyboardConfiguration.nextModeOutput,
                                  KeyboardConfiguration.settingsOutput] {
            XCTAssertFalse(output.repeatsWhileHeld, "\(output) が繰り返しになっている")
        }
    }

    /// カーソルキーは左右フリックで向きが決まる。**その出力が繰り返しの対象**。
    /// タップは向きが決まらないので何もしない＝繰り返さない。
    func testCursorKeyRepeatsOnlyWhenFlicked() {
        let column = KeyboardConfiguration.keyboardExtension.normalizedFunctionColumn
        let cursor = column.first { $0.title == "◀▶" }!
        let key = KeyKind.function(cursor)

        XCTAssertEqual(key.output(for: .left), .cursor(-1))
        XCTAssertEqual(key.output(for: .right), .cursor(1))
        XCTAssertTrue(key.output(for: .left).repeatsWhileHeld)
        XCTAssertTrue(key.output(for: .right).repeatsWhileHeld)
        XCTAssertFalse(key.output(for: .center).repeatsWhileHeld)
    }
}
