import XCTest
@testable import SplitKanaKit

final class DakutenCycleTests: XCTestCase {

    func testSmallFormComesFirst() {
        // 小書き → 濁点 → 半濁点（SPEC 2.4）
        XCTAssertEqual(DakutenCycle.next(after: "つ"), "っ")
        XCTAssertEqual(DakutenCycle.next(after: "っ"), "づ")
        XCTAssertEqual(DakutenCycle.next(after: "づ"), "つ")

        XCTAssertEqual(DakutenCycle.next(after: "う"), "ぅ")
        XCTAssertEqual(DakutenCycle.next(after: "ぅ"), "ゔ")
        XCTAssertEqual(DakutenCycle.next(after: "ゔ"), "う")
    }

    func testHandakutenOrder() {
        XCTAssertEqual(DakutenCycle.next(after: "は"), "ば")
        XCTAssertEqual(DakutenCycle.next(after: "ば"), "ぱ")
        XCTAssertEqual(DakutenCycle.next(after: "ぱ"), "は")
    }

    func testEveryKeyWithASmallFormReachesItFirst() {
        for base: Character in ["あ", "う", "つ", "や", "ゆ", "よ", "わ"] {
            let next = DakutenCycle.next(after: base)
            XCTAssertNotNil(next, "\(base) に巡回先がない")
            XCTAssertTrue(smallForms.contains(next!), "\(base) の1回目が小書きでない: \(next!)")
        }
    }

    func testCyclesAreClosed() {
        for ring in DakutenCycle.rings {
            var current = ring[0]
            for _ in ring {
                guard let next = DakutenCycle.next(after: current) else {
                    return XCTFail("\(current) が巡回から抜けた")
                }
                current = next
            }
            XCTAssertEqual(current, ring[0], "リング \(ring) が先頭に戻らない")
        }
    }

    func testCharactersWithoutVariantsAreInert() {
        for character: Character in ["な", "に", "ま", "ら", "を", "ん", "ー", "、", "A"] {
            XCTAssertNil(DakutenCycle.next(after: character), "\(character) が巡回してしまう")
        }
    }

    private let smallForms: Set<Character> = ["ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "っ", "ゃ", "ゅ", "ょ", "ゎ"]
}
