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

    /// **左手で打つ字は左、右手で打つ字は右。**G と B は左手の人差し指なので左。
    func testQwertyOrderFollowsTypingHands() {
        let g = geometry()
        XCTAssertTrue(g.isSplit)
        XCTAssertEqual(labels(panel(.left, g)),
                       ["q", "w", "e", "r", "t",
                        "a", "s", "d", "f", "g",
                        "⇧", "z", "x", "c", "v", "b",
                        "🌐", "⚙", "かな", "空白"])
        XCTAssertEqual(labels(panel(.right, g)),
                       ["y", "u", "i", "o", "p",
                        "h", "j", "k", "l",
                        "b", "n", "m", ",", ".", "⌫",
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

    /// 左右で列数が揃わなくてよい。打つ手のほうを優先した結果。
    func testPanelWidthsFollowTheirLongestRow() {
        let g = geometry()
        XCTAssertEqual(panel(.left, g).frame.width,
                       g.keyWidth * 6 + g.gapX * 5, accuracy: 0.5)
        XCTAssertEqual(panel(.right, g).frame.width,
                       g.keyWidth * 6 + g.gapX * 5, accuracy: 0.5)
    }

    /// B は左右どちらのパネルにもある。かなの あ列 と同じ重複（SPEC 2.1）。
    func testBAppearsOnBothPanels() {
        for shifted in [false, true] {
            let g = geometry(shifted: shifted)
            let letter = shifted ? "B" : "b"
            let left = panel(.left, g).keys.first { $0.key.kind.label == letter }!
            let right = panel(.right, g).keys.first { $0.key.kind.label == letter }!

            // 出力は完全に同一。違いは見た目だけ（SPEC 10）。
            XCTAssertEqual(left.key.kind.output(for: .center),
                           right.key.kind.output(for: .center))
            XCTAssertFalse(left.isDuplicate)
            XCTAssertTrue(right.isDuplicate)
        }
    }

    /// B は N の左。N から右のキーはこれまでの位置から動かない。
    func testDuplicateBSitsLeftOfN() {
        let g = geometry()
        let keys = panel(.right, g).keys
        let b = keys.first { $0.key.kind.label == "b" }!
        let n = keys.first { $0.key.kind.label == "n" }!
        XCTAssertEqual(b.rect.midY, n.rect.midY, accuracy: 0.5)
        XCTAssertEqual(n.rect.minX - b.rect.minX, g.keyWidth + g.gapX, accuracy: 0.5)
        // かつて N があった場所（左から1列目）に N が残っていること。
        XCTAssertEqual(n.rect.minX, g.keyWidth + g.gapX, accuracy: 0.5)
    }

    func testCommaAndPeriodAreAscii() {
        for shifted in [false, true] {
            let keys = panel(.right, geometry(shifted: shifted)).keys
            let comma = keys.first { $0.key.kind.label == "," }!
            let period = keys.first { $0.key.kind.label == "." }!
            // ⇧ で化けない。英数モードなので半角のまま。
            XCTAssertEqual(comma.key.kind.output(for: .center), .insert(","))
            XCTAssertEqual(period.key.kind.output(for: .center), .insert("."))
        }
    }

    /// 段差は左パネルから右パネルへ続く。行が下がるごとに半キーずつ右へ。
    func testRowsAreStaggered() {
        let g = geometry()
        let step = (g.keyWidth + g.gapX) / 2

        let left = panel(.left, g)
        XCTAssertEqual(left.keys[5].rect.minX - left.keys[0].rect.minX, step, accuracy: 0.5)  // a
        XCTAssertEqual(left.keys[10].rect.minX, 0, accuracy: 0.5)                             // ⇧

        let right = panel(.right, g)
        let x = { (label: String) in right.keys.first { $0.key.kind.label == label }!.rect.minX }
        XCTAssertEqual(x("h") - x("y"), step, accuracy: 0.5)
        XCTAssertEqual(x("n") - x("y"), step * 2, accuracy: 0.5)
    }

    func testWideKeysSpanColumns() {
        let g = geometry()
        let space = panel(.right, g).keys.first { $0.key.kind == .space }!
        let newline = panel(.right, g).keys.first { $0.key.kind == .newline }!
        XCTAssertEqual(space.rect.width, g.keyWidth * 3 + g.gapX * 2, accuracy: 0.5)
        XCTAssertEqual(newline.rect.width, g.keyWidth * 3 + g.gapX * 2, accuracy: 0.5)
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

    /// 英数はかなより横幅を食う（左6列＋右5列）。それでも iPad 横なら分割は保つ。
    func testLatinStillSplitsOnPad() {
        XCTAssertTrue(geometry().isSplit)
        XCTAssertGreaterThan(geometry().centerGap, SplitKanaTuning.minimumCenterGap)
    }

    // MARK: - 分割できないとき

    /// 幅が足りなくても**かなの配列に落ちてはいけない**。
    /// 英数のまま左右をつないで1枚の QWERTY にする。
    func testNarrowScreenKeepsQwerty() {
        let g = KeyboardGeometry.make(
            containerSize: CGSize(width: 390, height: 700),
            isPad: false,
            configuration: latin(),
            deviceClass: .phonePortrait
        )

        XCTAssertFalse(g.isSplit)
        let all = labels(g.panels[0])
        XCTAssertEqual(all.prefix(5).joined(), "qwert")
        XCTAssertTrue(all.contains("g"))
        XCTAssertFalse(all.contains("あ"))

        // 左右がひと続きになっている。q から p までで11列ぶん（左6＋右の YUIOP 5）。
        let q = g.panels[0].keys[0]
        let p = g.panels[0].keys.first { $0.key.kind == .latin("p") }!
        XCTAssertEqual(p.rect.maxX - q.rect.minX,
                       g.keyWidth * 11 + g.gapX * 10, accuracy: 0.5)
        XCTAssertEqual(g.panels[0].frame.width,
                       g.keyWidth * 12 + g.gapX * 11, accuracy: 0.5)
    }

    func testNarrowScreenKeysStayInsidePanel() {
        let g = KeyboardGeometry.make(
            containerSize: CGSize(width: 390, height: 700),
            isPad: false,
            configuration: latin(),
            deviceClass: .phonePortrait
        )
        let panel = g.panels[0]
        for key in panel.keys {
            XCTAssertLessThanOrEqual(key.rect.maxX, panel.frame.width + 0.5, key.id)
        }
        // id が左右で衝突していないこと。衝突すると当たり判定が片方に吸われる。
        XCTAssertEqual(Set(panel.keys.map(\.id)).count, panel.keys.count)
    }
}
