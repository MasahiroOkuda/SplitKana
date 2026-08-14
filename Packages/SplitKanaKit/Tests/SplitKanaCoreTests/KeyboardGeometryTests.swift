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

        configuration.scale = 0.1
        let small = geometry(CGSize(width: 1180, height: 820), isPad: true, configuration: configuration)
        XCTAssertEqual(small.appliedScale, KeyboardConfiguration.scaleRange.lowerBound, accuracy: 0.001)
    }

    /// **小さい倍率を選んだこと自体は、分割をやめる理由にならない。**
    /// 分割の成否は画面に収まるか（fitScale）だけで決める。
    func testSmallScaleKeepsTheSplitLayout() {
        var configuration = config
        configuration.scale = KeyboardConfiguration.scaleRange.lowerBound

        for (size, isPad) in Self.deviceSizes where isPad || size.width > size.height {
            let g = geometry(size, isPad: isPad, configuration: configuration)
            XCTAssertTrue(g.isSplit, "\(size) で小さくしただけなのに統合レイアウトへ落ちた")
            XCTAssertEqual(g.appliedScale,
                           KeyboardConfiguration.scaleRange.lowerBound,
                           accuracy: 0.001,
                           "\(size) で指定した倍率が使われていない")
        }
    }

    // MARK: - 設定で動かせる寸法

    /// 上の余白は**キーの大きさを変えずに**キーボード全体の高さだけを変える。
    func testTopPaddingChangesHeightWithoutResizingKeys() {
        let size = CGSize(width: 1180, height: 820)
        var tight = config
        tight.topPadding = 0
        var loose = config
        loose.topPadding = 40

        let a = geometry(size, isPad: true, configuration: tight)
        let b = geometry(size, isPad: true, configuration: loose)

        XCTAssertEqual(a.keyWidth, b.keyWidth, accuracy: 0.001, "余白でキー幅が変わってはいけない")
        XCTAssertEqual(a.keyHeight, b.keyHeight, accuracy: 0.001, "余白でキー高が変わってはいけない")
        XCTAssertEqual(b.keyboardHeight - a.keyboardHeight, 40, accuracy: 0.5)
    }

    /// 左右位置は両パネルを内側へ寄せ、中央の空きをそのぶん狭める。
    func testSideInsetMovesBothPanelsInward() {
        let size = CGSize(width: 1180, height: 820)
        var near = config
        near.sideInset = 10
        var far = config
        far.sideInset = 60

        let a = geometry(size, isPad: true, configuration: near)
        let b = geometry(size, isPad: true, configuration: far)

        let aLeft = a.panels.first { $0.side == .left }!
        let bLeft = b.panels.first { $0.side == .left }!
        let aRight = a.panels.first { $0.side == .right }!
        let bRight = b.panels.first { $0.side == .right }!

        XCTAssertEqual(bLeft.frame.minX - aLeft.frame.minX, 50, accuracy: 0.5)
        XCTAssertEqual(aRight.frame.maxX - bRight.frame.maxX, 50, accuracy: 0.5)
        XCTAssertLessThan(b.centerGap, a.centerGap, "内側へ寄せたのに中央が狭まっていない")
    }

    /// 設定を省いたら端末別の既定値が使われる。
    func testOmittedOverridesFallBackToTheDeviceDefaults() {
        let size = CGSize(width: 1180, height: 820)
        let base = DeviceClass.padLandscape.baseMetrics
        var explicit = config
        explicit.topPadding = base.topPadding
        explicit.sideInset = base.sideInset

        let fallback = geometry(size, isPad: true)               // topPadding / sideInset は nil
        let same = geometry(size, isPad: true, configuration: explicit)

        XCTAssertEqual(fallback.keyboardHeight, same.keyboardHeight, accuracy: 0.001)
        XCTAssertEqual(fallback.panels.first { $0.side == .left }!.frame.minX,
                       same.panels.first { $0.side == .left }!.frame.minX,
                       accuracy: 0.001)
    }

    // MARK: - 拡張の高さ決め

    /// キーボード拡張は自分の高さを自分で決める（SPEC 4）。
    ///
    /// 高さに上限を与えずに1回計算し、その `keyboardHeight` を高さ制約に入れる。
    /// **そのあと同じ寸法で計算し直しても同じ結果にならないと、拡張の高さが毎回揺れる。**
    func testKeyboardHeightIsStableWhenFedBackAsTheContainerHeight() {
        let cases: [(CGFloat, Bool, DeviceClass)] = [
            (844, false, .phoneLandscape),
            (390, false, .phonePortrait),
            (820, true, .padPortrait),
            (1180, true, .padLandscape),
            (507, true, .padPortrait)      // iPad Split View
        ]
        let safeArea = SafeAreaInsets(leading: 59, trailing: 59, bottom: 21)

        for (width, isPad, deviceClass) in cases {
            // 高さ側で頭打ちにしないための十分大きな値。KeyboardRootView と同じやり方。
            let probe = KeyboardGeometry.make(
                containerSize: CGSize(width: width, height: 4000),
                safeArea: safeArea, isPad: isPad,
                configuration: config, deviceClass: deviceClass
            )
            let height = probe.keyboardHeight

            XCTAssertGreaterThan(height, 0, "幅 \(width) で高さが出ない")
            XCTAssertLessThan(height, 4000, "幅 \(width) で高さが青天井になっている")

            let settled = KeyboardGeometry.make(
                containerSize: CGSize(width: width, height: height),
                safeArea: safeArea, isPad: isPad,
                configuration: config, deviceClass: deviceClass
            )
            XCTAssertEqual(settled.keyboardHeight, height, accuracy: 0.5,
                           "幅 \(width) で高さが揺れる")
            XCTAssertEqual(settled.appliedScale, probe.appliedScale, accuracy: 0.001,
                           "幅 \(width) で倍率が揺れる")
            XCTAssertEqual(settled.isSplit, probe.isSplit,
                           "幅 \(width) で分割の有無が変わる")
            XCTAssertEqual(settled.deviceClass, deviceClass,
                           "幅 \(width) で端末クラスが変わる")
        }
    }

    /// 拡張はコンテナ高＝キーボード高で描く。
    ///
    /// **このときタッチ層がコンテナの外へ出てはいけない。**
    /// SwiftUI はクリップしないので、外へ出ても描画は正しいまま見える。
    /// だが UIKit のヒットテストは祖先ビューの外側を弾くので、
    /// **見た目は完璧なのにキーが一切反応しない**という形で壊れる。
    func testTouchLayerStaysInsideTheContainerWhenSizedToTheKeyboard() {
        let cases: [(CGFloat, Bool, DeviceClass)] = [
            (844, false, .phoneLandscape),
            (390, false, .phonePortrait),
            (820, true, .padPortrait),
            (1180, true, .padLandscape),
            (507, true, .padPortrait)
        ]
        let outset = SplitKanaTuning.touchOutset

        // セーフエリアの有無どちらでも成り立つこと。ズレるのはここが効く場面。
        for safeArea in [SafeAreaInsets.zero,
                         SafeAreaInsets(leading: 59, trailing: 59, bottom: 21)] {
            for (width, isPad, deviceClass) in cases {
                let height = KeyboardGeometry.make(
                    containerSize: CGSize(width: width, height: 4000),
                    safeArea: safeArea, isPad: isPad,
                    configuration: config, deviceClass: deviceClass
                ).keyboardHeight

                let g = KeyboardGeometry.make(
                    containerSize: CGSize(width: width, height: height),
                    safeArea: safeArea, isPad: isPad,
                    configuration: config, deviceClass: deviceClass
                )

                let container = CGRect(x: 0, y: 0, width: width, height: height)

                for panel in g.panels {
                    // パネルそのものは必ず全部入っていること。
                    // ここが欠けると、そのぶんのキーが押せなくなる。
                    XCTAssertGreaterThanOrEqual(panel.frame.minY, -0.5,
                        "\(deviceClass) \(safeArea) でパネルが上にはみ出す（キーが反応しなくなる）")
                    XCTAssertLessThanOrEqual(panel.frame.maxY, height + 0.5,
                        "\(deviceClass) \(safeArea) でパネルが下にはみ出す")
                    XCTAssertGreaterThanOrEqual(panel.frame.minX, -0.5,
                        "\(deviceClass) \(safeArea) でパネルが左にはみ出す")
                    XCTAssertLessThanOrEqual(panel.frame.maxX, width + 0.5,
                        "\(deviceClass) \(safeArea) でパネルが右にはみ出す")

                    // タッチ層はビュー側でコンテナに収まるようクランプする。
                    // クランプ後もパネル全体を覆えていること。
                    let touch = panel.frame.insetBy(dx: -outset, dy: -outset)
                        .intersection(container)
                    XCTAssertEqual(touch.union(panel.frame), touch,
                        "\(deviceClass) \(safeArea) でクランプがパネルを削っている")
                }
            }
        }
    }

    /// 拡張のコンテナは横長で背が低い。**縦横比から判定させてはいけない。**
    func testExplicitDeviceClassOverridesTheAspectRatio() {
        let strip = CGSize(width: 844, height: 240)   // 拡張の入力ビューの形
        let inferred = geometry(strip, isPad: false)
        let explicit = KeyboardGeometry.make(
            containerSize: strip, isPad: false,
            configuration: config, deviceClass: .phoneLandscape
        )
        XCTAssertEqual(inferred.deviceClass, .phoneLandscape)   // この形なら推論も一致する
        XCTAssertEqual(explicit.deviceClass, .phoneLandscape)

        // 縦長に見えるコンテナでも、指定した端末クラスが勝つ。
        let tall = KeyboardGeometry.make(
            containerSize: CGSize(width: 844, height: 4000), isPad: false,
            configuration: config, deviceClass: .phoneLandscape
        )
        XCTAssertEqual(tall.deviceClass, .phoneLandscape)
        XCTAssertTrue(tall.isSplit)
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
