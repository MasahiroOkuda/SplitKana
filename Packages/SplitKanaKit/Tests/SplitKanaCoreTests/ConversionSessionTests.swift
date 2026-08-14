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

// MARK: - 表示用の導出（SPEC 5.2）

extension ConversionSessionTests {

    func testPositionIsOneBased() {
        let session = ConversionSession(reading: "かん", candidates: ["感", "缶", "巻"], selection: 1)
        XCTAssertEqual(session.position?.index, 2)
        XCTAssertEqual(session.position?.total, 3)
    }

    func testPositionIsNilWhenNotComposing() {
        XCTAssertNil(ConversionSession.empty.position)
    }

    /// 候補が無いときも読みを1件として数える。表示側に場合分けを持たせないため。
    func testPositionCountsTheReadingWhenThereAreNoCandidates() {
        let session = ConversionSession(reading: "ぬ", candidates: [], selection: 0)
        XCTAssertEqual(session.displayCandidates, ["ぬ"])
        XCTAssertEqual(session.position?.index, 1)
        XCTAssertEqual(session.position?.total, 1)
    }
}

/// **読みを見失わないことの確認。**
///
/// 候補が10件以上ある長めの読みで最後まで送っても、読みは一度も消えず、
/// 位置は常に 1..total に収まっていなければならない。
final class ConversionDisplayWalkthroughTests: XCTestCase {

    func testWalkingThroughTwelveCandidatesNeverLosesTheReading() {
        let reading = "かんがえ"
        let candidates = (1...12).map { "候補\($0)" }
        var controller = ConversionController(
            converter: FakeConverter(table: [reading: candidates]),
            session: ConversionSession(reading: reading, candidates: candidates, selection: 0)
        )

        for step in 0..<(candidates.count * 2) {
            let session = controller.session
            XCTAssertEqual(session.reading, reading, "\(step)回目の送りで読みが変わった")
            XCTAssertTrue(session.isComposing, "\(step)回目の送りで変換中でなくなった")

            let position = session.position
            XCTAssertNotNil(position, "\(step)回目で位置が出せない")
            XCTAssertEqual(position?.total, 12)
            XCTAssertGreaterThanOrEqual(position?.index ?? 0, 1)
            XCTAssertLessThanOrEqual(position?.index ?? 0, 12)

            _ = controller.handle(.space)
        }

        // 一周して戻ってきても読みは無事。
        XCTAssertEqual(controller.session.reading, reading)
        XCTAssertEqual(controller.session.position?.index, 1, "24回送れば先頭に戻る")
    }

    func testConfirmingClearsEverything() {
        var controller = ConversionController(
            converter: FakeConverter(table: ["かんがえ": ["考え", "勘が絵"]]),
            session: ConversionSession(reading: "かんがえ", candidates: ["考え", "勘が絵"], selection: 0)
        )
        _ = controller.handle(.newline)
        XCTAssertFalse(controller.session.isComposing)
        XCTAssertNil(controller.session.position, "確定したら表示は消える")
        XCTAssertTrue(controller.session.displayCandidates.isEmpty)
    }
}
