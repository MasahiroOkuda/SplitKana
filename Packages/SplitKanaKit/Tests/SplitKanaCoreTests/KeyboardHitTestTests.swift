import XCTest
import Foundation
@testable import SplitKanaCore

final class KeyboardHitTestTests: XCTestCase {

    private func phoneLandscape() -> KeyboardGeometry {
        KeyboardGeometry.make(
            containerSize: CGSize(width: 844, height: 390),
            safeArea: SafeAreaInsets(leading: 59, trailing: 59, bottom: 21),
            isPad: false,
            configuration: .keyboardExtension
        )
    }

    private func center(of panel: PanelGeometry, _ placed: PlacedKey) -> CGPoint {
        CGPoint(x: panel.frame.minX + placed.rect.minX + placed.rect.width / 2,
                y: panel.frame.minY + placed.rect.minY + placed.rect.height / 2)
    }

    func testEveryKeyIsHitAtItsOwnCentre() {
        let g = phoneLandscape()
        for panel in g.panels {
            for placed in panel.keys {
                let hit = g.hitTest(center(of: panel, placed))
                XCTAssertEqual(hit?.keyID, placed.id, "\(placed.id) の中心で別のキーが当たる")
                XCTAssertEqual(hit?.panelID, panel.id)
            }
        }
    }

    func testPointsOutsideThePanelsMissEverything() {
        let g = phoneLandscape()
        // 中央の空きと、キーボードより上。ホストが自由に使える領域なので当たってはいけない。
        XCTAssertNil(g.hitTest(CGPoint(x: 422, y: 200)))
        XCTAssertNil(g.hitTest(CGPoint(x: 422, y: 40)))
        XCTAssertNil(g.hitTest(CGPoint(x: 10, y: 10)))
        XCTAssertNil(g.hitTest(CGPoint(x: -5, y: 200)))
    }

    func testTapAreaExtendsBeyondTheVisibleKey() {
        let g = phoneLandscape()
        let panel = g.panels.first { $0.side == .left }!
        let placed = panel.keys.first { $0.key.kind.flickSet != nil }!
        // 見た目の左端より 1pt 外側。SPEC 10 の 2pt の余裕に入るので当たるはず。
        let justOutside = CGPoint(x: panel.frame.minX + placed.rect.minX - 1,
                                  y: panel.frame.minY + placed.rect.minY + placed.rect.height / 2)
        XCTAssertEqual(g.hitTest(justOutside)?.keyID, placed.id)
    }

    func testTwoSimultaneousPointsResolveToDifferentPanels() {
        let g = phoneLandscape()
        let left = g.panels.first { $0.side == .left }!
        let right = g.panels.first { $0.side == .right }!
        let a = g.hitTest(center(of: left, left.keys[4]))    // 左のあ列
        let b = g.hitTest(center(of: right, right.keys[8]))  // 右のさ列あたり
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertNotEqual(a?.keyID, b?.keyID)
        XCTAssertEqual(a?.panelID, "panel.left")
        XCTAssertEqual(b?.panelID, "panel.right")
    }

    func testDuplicateKeysHitAsTheSameKind() {
        let g = phoneLandscape()
        let left = g.panels.first { $0.side == .left }!
        let right = g.panels.first { $0.side == .right }!
        let leftA = left.keys.first { $0.key.kind == .kana(FlickTable.a) }!
        let rightA = right.keys.first { $0.key.kind == .kana(FlickTable.a) }!
        let a = g.hitTest(center(of: left, leftA))
        let b = g.hitTest(center(of: right, rightA))
        XCTAssertNotEqual(a?.keyID, b?.keyID, "識別子は別でよい")
        // どちらを押しても同じ出力になる（SPEC 2.1 / 10）
        XCTAssertEqual(a?.key.kind, b?.key.kind)
        XCTAssertEqual(a?.key.kind.baseOutput, b?.key.kind.baseOutput)
    }

    func testNewlineIsHitAcrossBothOfItsRows() {
        let g = phoneLandscape()
        let right = g.panels.first { $0.side == .right }!
        let newline = right.keys.first { $0.key.kind == .newline }!
        let top = CGPoint(x: right.frame.minX + newline.rect.minX + newline.rect.width / 2,
                          y: right.frame.minY + newline.rect.minY + g.keyHeight * 0.5)
        let bottom = CGPoint(x: right.frame.minX + newline.rect.minX + newline.rect.width / 2,
                             y: right.frame.minY + newline.rect.maxY - g.keyHeight * 0.5)
        XCTAssertEqual(g.hitTest(top)?.keyID, newline.id)
        XCTAssertEqual(g.hitTest(bottom)?.keyID, newline.id)
    }

    func testHitTestNeverReturnsTwoKeysForOnePoint() {
        // 広げた縁が重なっても、必ずどれか1つに決まること。
        let g = phoneLandscape()
        let panel = g.panels.first { $0.side == .right }!
        var seen = 0
        var x = panel.frame.minX
        while x <= panel.frame.maxX {
            var y = panel.frame.minY
            while y <= panel.frame.maxY {
                if g.hitTest(CGPoint(x: x, y: y)) != nil { seen += 1 }
                y += 3
            }
            x += 3
        }
        XCTAssertGreaterThan(seen, 0)
    }

    func testUnifiedLayoutIsHittableToo() {
        let g = KeyboardGeometry.make(
            containerSize: CGSize(width: 390, height: 844),
            isPad: false,
            configuration: .keyboardExtension
        )
        XCTAssertFalse(g.isSplit)
        let panel = g.panels[0]
        for placed in panel.keys {
            XCTAssertEqual(g.hitTest(center(of: panel, placed))?.keyID, placed.id)
        }
    }
}
