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
