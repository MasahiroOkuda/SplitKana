import XCTest
import CoreGraphics
@testable import SplitKanaKit

final class KeyboardGeometryTests: XCTestCase {

    private let config = KeyboardConfiguration.hostApp

    private func geometry(_ size: CGSize, isPad: Bool, configuration: KeyboardConfiguration? = nil) -> KeyboardGeometry {
        KeyboardGeometry.make(
            containerSize: size,
            safeArea: SafeAreaInsets(leading: 0, trailing: 0, bottom: 0),
            isPad: isPad,
            configuration: configuration ?? config
        )
    }

    func testPhoneLandscapeSplits() {
        let g = geometry(CGSize(width: 844, height: 390), isPad: false)
        XCTAssertTrue(g.isSplit)
        XCTAssertEqual(g.panels.count, 2)
        XCTAssertGreaterThan(g.centerGap, SplitKanaTuning.minimumCenterGap)
        XCTAssertLessThanOrEqual(g.keyboardHeight, 390)
    }

    func testPhonePortraitFallsBackToFiveColumns() {
        let g = geometry(CGSize(width: 390, height: 844), isPad: false)
        XCTAssertFalse(g.isSplit)
        XCTAssertEqual(g.panels.count, 1)
        XCTAssertEqual(g.panels[0].side, .unified)
        // 機能列 / あ列 / か列 / さ列 / 機能列 = 5列（SPEC 3.3）
        let columnCount = Set(g.panels[0].keys.map { ($0.rect.minX * 100).rounded() }).count
        XCTAssertEqual(columnCount, 5)
        XCTAssertFalse(g.panels[0].keys.contains { $0.isDuplicate })
    }

    func testPanelsFitInsideContainer() {
        let sizes: [(CGSize, Bool)] = [
            (CGSize(width: 844, height: 390), false),
            (CGSize(width: 390, height: 844), false),
            (CGSize(width: 820, height: 1180), true),
            (CGSize(width: 1180, height: 820), true),
            (CGSize(width: 507, height: 1180), true)   // iPad Split View
        ]
        for (size, isPad) in sizes {
            let g = geometry(size, isPad: isPad)
            for panel in g.panels {
                XCTAssertGreaterThanOrEqual(panel.frame.minX, 0, "\(size) ではみ出し")
                XCTAssertLessThanOrEqual(panel.frame.maxX, size.width + 0.5, "\(size) ではみ出し")
                XCTAssertLessThanOrEqual(panel.frame.maxY, size.height + 0.5, "\(size) ではみ出し")
                for key in panel.keys {
                    XCTAssertLessThanOrEqual(key.rect.maxX, panel.frame.width + 0.5)
                    XCTAssertLessThanOrEqual(key.rect.maxY, panel.frame.height + 0.5)
                }
            }
        }
    }

    func testDuplicateColumnIsOnlyTheRightPanelsFirstColumn() {
        let g = geometry(CGSize(width: 1180, height: 820), isPad: true)
        let left = g.panels.first { $0.side == .left }!
        let right = g.panels.first { $0.side == .right }!
        XCTAssertFalse(left.keys.contains { $0.isDuplicate })
        XCTAssertEqual(right.keys.filter(\.isDuplicate).count, 4)
        XCTAssertTrue(right.keys.filter(\.isDuplicate).allSatisfy { $0.rect.minX == 0 })
    }

    func testDuplicateKeysProduceIdenticalOutput() {
        let g = geometry(CGSize(width: 1180, height: 820), isPad: true)
        let left = g.panels.first { $0.side == .left }!
        let right = g.panels.first { $0.side == .right }!
        let leftKana = left.keys.filter { $0.key.kind.flickSet != nil || $0.key.kind == .dakuten }
        let duplicated = right.keys.filter(\.isDuplicate)
        XCTAssertEqual(leftKana.map(\.key.kind), duplicated.map(\.key.kind))
    }

    func testThreeColumnRightPanelDropsDuplicates() {
        var configuration = KeyboardConfiguration.hostApp
        configuration.showsDuplicateColumn = false
        let g = geometry(CGSize(width: 844, height: 390), isPad: false, configuration: configuration)
        let right = g.panels.first { $0.side == .right }!
        XCTAssertFalse(right.keys.contains { $0.isDuplicate })
        XCTAssertEqual(Set(right.keys.map { $0.rect.minX }).count, 3)
    }

    func testPopupsOpenTowardTheCentre() {
        let g = geometry(CGSize(width: 844, height: 390), isPad: false)
        let left = g.panels.first { $0.side == .left }!
        let right = g.panels.first { $0.side == .right }!
        XCTAssertTrue(left.keys.allSatisfy { $0.popupSide == .trailing })
        XCTAssertTrue(right.keys.allSatisfy { $0.popupSide == .leading })
    }

    func testNewlineSpansTwoRows() {
        let g = geometry(CGSize(width: 844, height: 390), isPad: false)
        let right = g.panels.first { $0.side == .right }!
        let newline = right.keys.first { $0.key.kind == .newline }!
        XCTAssertEqual(newline.key.rowSpan, 2)
        XCTAssertEqual(newline.rect.height, g.keyHeight * 2 + g.gapY, accuracy: 0.001)
        XCTAssertEqual(newline.rect.maxY, right.frame.height, accuracy: 0.001)
    }

    func testDimensionModelMatchesSpec() {
        let g = geometry(CGSize(width: 1180, height: 820), isPad: true)
        let left = g.panels.first { $0.side == .left }!
        let right = g.panels.first { $0.side == .right }!
        // 左パネル幅 = 2×kw + gx / 右パネル幅 = 4×kw + 3×gx（SPEC 3.1）
        XCTAssertEqual(left.frame.width, 2 * g.keyWidth + g.gapX, accuracy: 0.001)
        XCTAssertEqual(right.frame.width, 4 * g.keyWidth + 3 * g.gapX, accuracy: 0.001)
        XCTAssertEqual(left.frame.height, 4 * g.keyHeight + 3 * g.gapY, accuracy: 0.001)
    }

    func testFreeRegionSitsBetweenThePanels() {
        let g = geometry(CGSize(width: 1180, height: 820), isPad: true)
        let left = g.panels.first { $0.side == .left }!
        let right = g.panels.first { $0.side == .right }!
        XCTAssertGreaterThanOrEqual(g.freeRegion.minX, left.frame.maxX)
        XCTAssertLessThanOrEqual(g.freeRegion.maxX, right.frame.minX)
        XCTAssertGreaterThan(g.freeRegion.width, 300)
    }

    func testSafeAreaShiftsPanelOrigins() {
        let plain = geometry(CGSize(width: 844, height: 390), isPad: false)
        let notched = KeyboardGeometry.make(
            containerSize: CGSize(width: 844, height: 390),
            safeArea: SafeAreaInsets(leading: 59, trailing: 59, bottom: 21),
            isPad: false,
            configuration: config
        )
        let plainLeft = plain.panels.first { $0.side == .left }!
        let notchedLeft = notched.panels.first { $0.side == .left }!
        XCTAssertGreaterThan(notchedLeft.frame.minX, plainLeft.frame.minX)
        XCTAssertLessThanOrEqual(notched.panels.first { $0.side == .right }!.frame.maxX, 844 - 59)
    }

    func testScaleIsClampedToTheAllowedRange() {
        var configuration = KeyboardConfiguration.hostApp
        configuration.scale = 5
        let g = geometry(CGSize(width: 1180, height: 820), isPad: true, configuration: configuration)
        XCTAssertLessThanOrEqual(g.appliedScale, KeyboardConfiguration.scaleRange.upperBound)
    }
}
