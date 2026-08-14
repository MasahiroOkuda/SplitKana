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

    /// ポップアップはかなキーだけ。空白にフリックを足しても出さない。
    func testSpaceHasNoPopup() {
        XCTAssertNil(KeyKind.space.flickSet)
    }
}
