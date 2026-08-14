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
        let set = FlickSet("か", "き", "く", "け", "こ")
        XCTAssertEqual(KeyKind.kana(set).output(for: .up), .insert("く"))
        XCTAssertEqual(KeyKind.kana(set).output(for: .center), .insert("か"))
    }

    /// 空白以外の機能キーは方向を無視する。
    func testOtherKeysIgnoreDirection() {
        XCTAssertEqual(KeyKind.backspace.output(for: .left), .backspace)
        XCTAssertEqual(KeyKind.newline.output(for: .left), .newline)
        XCTAssertEqual(KeyKind.dakuten.output(for: .left), .dakuten)
    }

    // MARK: - 機能キーのフリック

    /// **1つのキーで左右を兼ねる。**機能列は4席しか無いので席を節約する。
    func testCursorKeyMovesEitherWayByFlick() {
        let key = FunctionKey(
            title: "◀▶",
            output: .custom("noop"),
            flickOutputs: [.left: .cursor(-1), .right: .cursor(1)]
        )
        XCTAssertEqual(KeyKind.function(key).output(for: .left), .cursor(-1))
        XCTAssertEqual(KeyKind.function(key).output(for: .right), .cursor(1))
    }

    /// 指定の無い方向はタップと同じ出力に落ちる。
    func testUnassignedDirectionsFallBackToTheTapOutput() {
        let key = FunctionKey(
            title: "◀▶",
            output: .custom("noop"),
            flickOutputs: [.left: .cursor(-1), .right: .cursor(1)]
        )
        for direction in [FlickDirection.center, .up, .down] {
            XCTAssertEqual(KeyKind.function(key).output(for: direction), .custom("noop"),
                           "\(direction) は何もしない")
        }
    }

    /// フリックを持たない機能キーは今までどおり方向を無視する。
    func testPlainFunctionKeysIgnoreDirection() {
        let key = FunctionKey(title: "🌐", output: .nextInputMode)
        for direction in FlickDirection.allCases {
            XCTAssertEqual(KeyKind.function(key).output(for: direction), .nextInputMode)
        }
    }

    /// 機能キーにフリックを足してもポップアップは出さない。
    func testFunctionKeysHaveNoPopup() {
        let key = FunctionKey(title: "◀▶", output: .custom("noop"),
                              flickOutputs: [.left: .cursor(-1)])
        XCTAssertNil(KeyKind.function(key).flickSet)
    }

    /// ポップアップはかなキーだけ。空白にフリックを足しても出さない。
    func testSpaceHasNoPopup() {
        XCTAssertNil(KeyKind.space.flickSet)
    }
}
