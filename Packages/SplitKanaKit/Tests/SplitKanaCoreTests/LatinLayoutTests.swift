import XCTest
import Foundation
@testable import SplitKanaCore

/// 英数モード（QWERTY）の配置（SPEC 2.6）。
final class LatinLayoutTests: XCTestCase {

    private func latin(shifted: Bool = false) -> KeyboardConfiguration {
        var config = KeyboardConfiguration.keyboardExtension
        config.mode = .latin
        config.isShifted = shifted
        return config
    }

    private func geometry(shifted: Bool = false) -> KeyboardGeometry {
        KeyboardGeometry.make(
            containerSize: CGSize(width: 1180, height: 500),
            isPad: true,
            configuration: latin(shifted: shifted),
            deviceClass: .padLandscape
        )
    }

    private func labels(_ panel: PanelGeometry) -> [String] {
        panel.keys.map { $0.key.kind.label }
    }

    private func panel(_ side: PanelSide, _ g: KeyboardGeometry) -> PanelGeometry {
        g.panels.first { $0.side == side }!
    }

    // MARK: - 並び

    func testQwertyOrder() {
        let g = geometry()
        XCTAssertTrue(g.isSplit)
        XCTAssertEqual(labels(panel(.left, g)),
                       ["q", "w", "e", "r", "t",
                        "a", "s", "d", "f",
                        "⇧", "z", "x", "c", "v",
                        "🌐", "⚙", "かな", "空白"])
        XCTAssertEqual(labels(panel(.right, g)),
                       ["y", "u", "i", "o", "p",
                        "g", "h", "j", "k", "l",
                        "b", "n", "m", "⌫",
                        "空白", "改行"])
    }

    func testShiftUppercasesLetters() {
        let g = geometry(shifted: true)
        XCTAssertEqual(labels(panel(.left, g)).prefix(5).joined(), "QWERT")
        XCTAssertEqual(labels(panel(.right, g)).prefix(5).joined(), "YUIOP")
        // 機能キーは大文字化の対象外。
        XCTAssertTrue(labels(panel(.left, g)).contains("かな"))
    }

    func testLetterKeyInsertsItsOwnCase() {
        let lower = panel(.left, geometry()).keys[0]
        let upper = panel(.left, geometry(shifted: true)).keys[0]
        XCTAssertEqual(lower.key.kind.output(for: .center), .insert("q"))
        XCTAssertEqual(upper.key.kind.output(for: .center), .insert("Q"))
        // フリックしても英字は動かない。誤爆で別の文字が出ると直しようがない。
        XCTAssertEqual(upper.key.kind.output(for: .up), .insert("Q"))
    }

    // MARK: - 幅と段差

    func testPanelsAreFiveColumnsWide() {
        let g = geometry()
        let expected = g.keyWidth * 5 + g.gapX * 4
        XCTAssertEqual(panel(.left, g).frame.width, expected, accuracy: 0.5)
        XCTAssertEqual(panel(.right, g).frame.width, expected, accuracy: 0.5)
    }

    func testHomeRowIsIndentedByHalfKey() {
        let g = geometry()
        let left = panel(.left, g)
        let q = left.keys[0]
        let a = left.keys[5]
        XCTAssertEqual(a.rect.minY - q.rect.minY, g.keyHeight + g.gapY, accuracy: 0.5)
        XCTAssertEqual(a.rect.minX - q.rect.minX, (g.keyWidth + g.gapX) / 2, accuracy: 0.5)
    }

    func testWideKeysSpanColumns() {
        let g = geometry()
        let space = panel(.right, g).keys.first { $0.key.kind == .space }!
        let newline = panel(.right, g).keys.first { $0.key.kind == .newline }!
        XCTAssertEqual(space.rect.width, g.keyWidth * 3 + g.gapX * 2, accuracy: 0.5)
        XCTAssertEqual(newline.rect.width, g.keyWidth * 2 + g.gapX, accuracy: 0.5)
        // 最終行は左端から右端まできっちり埋まる。
        XCTAssertEqual(newline.rect.maxX, panel(.right, g).frame.width, accuracy: 0.5)
    }

    func testNoKeyOverflowsItsPanel() {
        let g = geometry()
        for panel in g.panels {
            for key in panel.keys {
                XCTAssertGreaterThanOrEqual(key.rect.minX, -0.5, key.id)
                XCTAssertLessThanOrEqual(key.rect.maxX, panel.frame.width + 0.5, key.id)
                XCTAssertLessThanOrEqual(key.rect.maxY, panel.frame.height + 0.5, key.id)
            }
        }
    }

    func testKeysDoNotOverlap() {
        let g = geometry()
        for panel in g.panels {
            for (i, a) in panel.keys.enumerated() {
                for b in panel.keys[(i + 1)...] {
                    XCTAssertFalse(a.rect.intersects(b.rect), "\(a.id) と \(b.id) が重なっている")
                }
            }
        }
    }

    // MARK: - 当たり判定

    func testHitTestFindsLetterKeys() {
        let g = geometry()
        for panel in g.panels {
            for key in panel.keys {
                let point = CGPoint(x: panel.frame.minX + key.rect.midX,
                                    y: panel.frame.minY + key.rect.midY)
                XCTAssertEqual(g.hitTest(point)?.keyID, key.id)
            }
        }
    }

    // MARK: - かなとの独立

    func testKanaModeIsUnaffected() {
        let g = KeyboardGeometry.make(
            containerSize: CGSize(width: 1180, height: 500),
            isPad: true,
            configuration: .keyboardExtension,
            deviceClass: .padLandscape
        )
        // かなは左2列。英数の5列と取り違えていないこと。
        XCTAssertEqual(panel(.left, g).frame.width, g.keyWidth * 2 + g.gapX, accuracy: 0.5)
    }

    /// 英数はかなより横幅を食う（左右5列ずつ）。それでも分割が崩れないこと。
    func testLatinStillSplitsOnPad() {
        XCTAssertTrue(geometry().isSplit)
        XCTAssertGreaterThan(geometry().centerGap, SplitKanaTuning.minimumCenterGap)
    }
}
