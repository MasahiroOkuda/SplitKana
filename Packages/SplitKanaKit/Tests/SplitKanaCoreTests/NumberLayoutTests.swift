import XCTest
import Foundation
@testable import SplitKanaCore

/// 数字モード（SPEC 2.7）。かなと同じグリッドを使う。
final class NumberLayoutTests: XCTestCase {

    private func geometry(mode: InputMode) -> KeyboardGeometry {
        var config = KeyboardConfiguration.keyboardExtension
        config.mode = mode
        return KeyboardGeometry.make(
            containerSize: CGSize(width: 1180, height: 500),
            isPad: true,
            configuration: config,
            deviceClass: .padLandscape
        )
    }

    private func panel(_ side: PanelSide, _ g: KeyboardGeometry) -> PanelGeometry {
        g.panels.first { $0.side == side }!
    }

    /// 行で読むと日本語12キーの数字並びになる。
    ///
    /// ```
    /// 1 2 3
    /// 4 5 6
    /// 7 8 9
    /// ```
    func testDigitsFormTheJapaneseKeypad() {
        let g = geometry(mode: .number)
        let right = panel(.right, g)

        // 右パネルは あ列(複製) / か列 / さ列 / 機能列。左の3列が数字。
        var rows: [[String]] = []
        for row in 0..<3 {
            let y = CGFloat(row) * (g.keyHeight + g.gapY) + g.keyHeight / 2
            let line = right.keys
                .filter { abs($0.rect.midY - y) < 1 }
                .sorted { $0.rect.minX < $1.rect.minX }
                .prefix(3)
                .map { $0.key.kind.label }
            rows.append(Array(line))
        }
        XCTAssertEqual(rows, [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]])
    }

    /// あ列は右パネルに複製されるので 1・4・7 が両側に出る。
    /// かなの あ・た・ま と同じ重複（SPEC 2.1）。
    func testOneFourSevenAppearOnBothPanels() {
        let g = geometry(mode: .number)
        for digit in ["1", "4", "7"] {
            XCTAssertTrue(panel(.left, g).keys.contains { $0.key.kind.label == digit },
                          "\(digit) が左パネルにない")
            XCTAssertTrue(panel(.right, g).keys.contains { $0.key.kind.label == digit },
                          "\(digit) が右パネルにない")
        }
        // 複製元と複製先で出力が完全に同一であること（SPEC 2.1 / 10）。
        let left = panel(.left, g).keys.first { $0.key.kind.label == "1" }!
        let right = panel(.right, g).keys.first { $0.key.kind.label == "1" }!
        XCTAssertEqual(left.key.kind.output(for: .center), right.key.kind.output(for: .center))
        XCTAssertTrue(right.isDuplicate)
    }

    func testFourthRowHasZeroAndSeparators() {
        let g = geometry(mode: .number)
        let labels = panel(.right, g).keys.map { $0.key.kind.label }
        XCTAssertTrue(labels.contains("0"))
        XCTAssertTrue(labels.contains("."))
        XCTAssertTrue(labels.contains(","))
    }

    func testDigitsDoNotFlick() {
        let g = geometry(mode: .number)
        let five = panel(.right, g).keys.first { $0.key.kind.label == "5" }!
        for direction in [FlickDirection.center, .left, .up, .right, .down] {
            XCTAssertEqual(five.key.kind.output(for: direction), .insert("5"))
        }
        XCTAssertNil(five.key.kind.flickSet)
    }

    /// ⌫・空白・改行はモードを跨いで同じ場所にある。
    func testUtilityColumnStaysPut() {
        let kana = panel(.right, geometry(mode: .kana))
        let number = panel(.right, geometry(mode: .number))

        for kind in [KeyKind.backspace, .space, .newline] {
            let a = kana.keys.first { $0.key.kind == kind }!
            let b = number.keys.first { $0.key.kind == kind }!
            XCTAssertEqual(a.rect, b.rect, "\(kind.label) の位置が動いている")
        }
    }

    // MARK: - モードの巡回

    func testModeCyclesKanaNumberLatin() {
        XCTAssertEqual(InputMode.kana.next, .number)
        XCTAssertEqual(InputMode.number.next, .latin)
        XCTAssertEqual(InputMode.latin.next, .kana)
    }

    /// 切り替えキーには**押した先**を出す。いまのモードを出すと押す先が読めない。
    func testModeKeyShowsWhereItGoes() {
        for (mode, expected) in [(InputMode.kana, "123"), (.number, "ABC")] {
            var config = KeyboardConfiguration.keyboardExtension
            config.mode = mode
            let key = config.normalizedFunctionColumn.first {
                $0.output == KeyboardConfiguration.nextModeOutput
            }
            XCTAssertEqual(key?.title, expected)
        }
        // 英字モードの切り替えキーは左パネル下段にある。
        let bottom = LatinKeyTable.leftRows(shifted: false).last!.keys
        XCTAssertTrue(bottom.contains { $0.kind.label == "かな" })
    }
}
