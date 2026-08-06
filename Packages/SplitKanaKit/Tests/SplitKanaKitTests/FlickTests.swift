import XCTest
import CoreGraphics
@testable import SplitKanaKit

final class FlickTests: XCTestCase {

    func testDirectionOrderMatchesSpec() {
        // 中央 / 左 / 上 / 右 / 下 の順で あ い う え お
        let a = FlickTable.a
        XCTAssertEqual(a[.center], "あ")
        XCTAssertEqual(a[.left], "い")
        XCTAssertEqual(a[.up], "う")
        XCTAssertEqual(a[.right], "え")
        XCTAssertEqual(a[.down], "お")
    }

    func testEveryTableEntryHasFiveCharacters() {
        for set in FlickTable.all {
            XCTAssertEqual(set.assigned.count, 5, "\(set.center) の割り当てが5つでない")
        }
    }

    func testBelowThresholdIsCenter() {
        let threshold: CGFloat = 18
        XCTAssertEqual(FlickResolver.direction(translation: .zero, threshold: threshold), .center)
        XCTAssertEqual(FlickResolver.direction(translation: CGSize(width: 17, height: 17), threshold: threshold), .center)
        XCTAssertEqual(FlickResolver.direction(translation: CGSize(width: -17, height: 0), threshold: threshold), .center)
    }

    func testDominantAxisWins() {
        let threshold: CGFloat = 18
        XCTAssertEqual(FlickResolver.direction(translation: CGSize(width: -40, height: 10), threshold: threshold), .left)
        XCTAssertEqual(FlickResolver.direction(translation: CGSize(width: 40, height: -10), threshold: threshold), .right)
        XCTAssertEqual(FlickResolver.direction(translation: CGSize(width: 5, height: -40), threshold: threshold), .up)
        XCTAssertEqual(FlickResolver.direction(translation: CGSize(width: 5, height: 40), threshold: threshold), .down)
    }

    func testUnassignedDirectionFallsBackToCenter() {
        let set = FlickSet("あ")
        XCTAssertEqual(set.character(for: .up), "あ")
    }
}
