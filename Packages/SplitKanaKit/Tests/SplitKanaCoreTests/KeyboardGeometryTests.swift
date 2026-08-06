import XCTest
import Foundation
@testable import SplitKanaCore

final class KeyboardGeometryTests: XCTestCase {

    private let config = KeyboardConfiguration.keyboardExtension

    private func geometry(
        _ size: CGSize,
        isPad: Bool,
        safeArea: SafeAreaInsets = .zero,
        configuration: KeyboardConfiguration? = nil
    ) -> KeyboardGeometry {
        KeyboardGeometry.make(
            containerSize: size,
            safeArea: safeArea,
            isPad: isPad,
            configuration: configuration ?? config
        )
    }

    // MARK: - 分割の成立

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
        for (size, isPad) in Self.deviceSizes {
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

    // MARK: - 複製列

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
        var configuration = config
        configuration.showsDuplicateColumn = false
        let g = geometry(CGSize(width: 844, height: 390), isPad: false, configuration: configuration)
        let right = g.panels.first { $0.side == .right }!
        XCTAssertFalse(right.keys.contains { $0.isDuplicate })
        XCTAssertEqual(Set(right.keys.map { $0.rect.minX }).count, 3)
    }

    // MARK: - 寸法モデル

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
        let size = CGSize(width: 844, height: 390)
        let plain = geometry(size, isPad: false)
        let notched = geometry(size, isPad: false,
                               safeArea: SafeAreaInsets(leading: 59, trailing: 59, bottom: 21))
        let plainLeft = plain.panels.first { $0.side == .left }!
        let notchedLeft = notched.panels.first { $0.side == .left }!
        XCTAssertGreaterThan(notchedLeft.frame.minX, plainLeft.frame.minX)
        XCTAssertLessThanOrEqual(notched.panels.first { $0.side == .right }!.frame.maxX, 844 - 59)
    }

    func testScaleIsClampedToTheAllowedRange() {
        var configuration = config
        configuration.scale = 5
        let g = geometry(CGSize(width: 1180, height: 820), isPad: true, configuration: configuration)
        XCTAssertLessThanOrEqual(g.appliedScale, KeyboardConfiguration.scaleRange.upperBound)
    }

    // MARK: - ポップアップの置き場所

    func testPopupNeverCoversAnyKey() {
        for (size, isPad) in Self.deviceSizes where isPad || size.width > size.height {
            let g = geometry(size, isPad: isPad,
                             safeArea: SafeAreaInsets(leading: 59, trailing: 59, bottom: 21))
            guard g.isSplit else { continue }
            for panel in g.panels {
                for key in panel.keys {
                    guard let flickSet = key.key.kind.flickSet else { continue }
                    let placement = g.popupPlacement(for: key, itemCount: flickSet.assigned.count)
                    XCTAssertNotNil(placement, "\(size) の \(key.id) でポップアップが置けない")
                    guard let rect = placement?.rect else { continue }
                    for other in g.panels {
                        XCTAssertFalse(Self.overlaps(rect, other.frame),
                                       "\(size) の \(key.id) のポップアップが \(other.id) に重なる")
                    }
                }
            }
        }
    }

    func testPopupIsPinnedToThePanelEdgeNotToTheKey() {
        let g = geometry(CGSize(width: 844, height: 390), isPad: false)
        for panel in g.panels {
            let xs = panel.keys.compactMap { key -> CGFloat? in
                guard let flickSet = key.key.kind.flickSet else { return nil }
                return g.popupPlacement(for: key, itemCount: flickSet.assigned.count)?.rect.minX
            }
            XCTAssertGreaterThan(xs.count, 1)
            // どのキーを押しても横位置は動かない。
            XCTAssertEqual(Set(xs).count, 1, "\(panel.id) のポップアップがキーごとに動いている")
        }
    }

    func testPopupStaysInsideTheContainerAndThePanelRows() {
        for (size, isPad) in Self.deviceSizes {
            let g = geometry(size, isPad: isPad)
            for panel in g.panels {
                for key in panel.keys {
                    guard let flickSet = key.key.kind.flickSet,
                          let placement = g.popupPlacement(for: key, itemCount: flickSet.assigned.count)
                    else { continue }
                    let rect = placement.rect
                    XCTAssertGreaterThanOrEqual(rect.minX, -0.5, "\(size) で左にはみ出し")
                    XCTAssertLessThanOrEqual(rect.maxX, size.width + 0.5, "\(size) で右にはみ出し")
                    XCTAssertGreaterThanOrEqual(rect.minY, panel.frame.minY - 0.5)
                    XCTAssertLessThanOrEqual(rect.maxY, panel.frame.maxY + 0.5)
                }
            }
        }
    }

    func testPopupTracksTheRowOfThePressedKey() {
        let g = geometry(CGSize(width: 1180, height: 820), isPad: true)
        let left = g.panels.first { $0.side == .left }!
        let kana = left.keys.filter { $0.key.kind.flickSet != nil }.sorted { $0.rect.minY < $1.rect.minY }
        let ys = kana.compactMap { g.popupPlacement(for: $0, itemCount: 5)?.rect.minY }
        XCTAssertEqual(ys.count, kana.count)
        // 上の行ほど上に出る（クランプで潰れない広さがある端末で確認）。
        XCTAssertEqual(ys, ys.sorted())
        XCTAssertGreaterThan(ys.last! - ys.first!, 0)
    }

    func testPopupIsNilForKeysWithoutFlicks() {
        let g = geometry(CGSize(width: 844, height: 390), isPad: false)
        let right = g.panels.first { $0.side == .right }!
        let backspace = right.keys.first { $0.key.kind == .backspace }!
        XCTAssertNil(g.popupPlacement(for: backspace, itemCount: 0))
    }

    // MARK: -

    private static let deviceSizes: [(CGSize, Bool)] = [
        (CGSize(width: 844, height: 390), false),   // iPhone 横
        (CGSize(width: 390, height: 844), false),   // iPhone 縦
        (CGSize(width: 820, height: 1180), true),   // iPad 縦
        (CGSize(width: 1180, height: 820), true),   // iPad 横
        (CGSize(width: 507, height: 1180), true)    // iPad Split View
    ]

    /// `CGRect.intersects` はプラットフォームによって挙動が揃わないので自前で判定する。
    private static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }
}
