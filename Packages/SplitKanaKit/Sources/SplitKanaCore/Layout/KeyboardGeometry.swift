import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public struct SafeAreaInsets: Equatable, Sendable {
    public var leading: CGFloat
    public var trailing: CGFloat
    public var bottom: CGFloat

    public init(leading: CGFloat = 0, trailing: CGFloat = 0, bottom: CGFloat = 0) {
        self.leading = leading
        self.trailing = trailing
        self.bottom = bottom
    }

    public static let zero = SafeAreaInsets()
}

public enum PanelSide: String, Sendable {
    case left
    case right
    /// 分割しない（iPhone 縦のフォールバック）
    case unified
}

/// フリックポップアップの開く向き。**必ずキーボードの外側（中央の空き）へ**（SPEC 2.3）。
public enum PopupSide: String, Sendable {
    case leading
    case trailing
}

public struct PlacedKey: Identifiable, Sendable {
    public let id: String
    public let key: KeyDescriptor
    /// パネル内座標での見た目の矩形
    public let rect: CGRect
    /// 右パネルのあ列（複製列）か。**イベントは複製元と完全に同一**（SPEC 2.1 / 10）。
    public let isDuplicate: Bool
    public let popupSide: PopupSide
}

public struct PanelGeometry: Identifiable, Sendable {
    public let id: String
    public let side: PanelSide
    /// コンテナ座標での矩形
    public let frame: CGRect
    public let keys: [PlacedKey]
}

/// フリックポップアップの置き場所。コンテナ座標。
public struct PopupPlacement: Equatable, Sendable {
    public let rect: CGRect
    public let itemWidth: CGFloat
    public let itemHeight: CGFloat
}

/// 毎回コンテナ寸法から計算するレイアウト結果（SPEC 3.1）。
///
/// ```
/// キー幅  kw = base_kw × scale
/// キー高  kh = base_kh × scale
/// 左パネル幅 = 2×kw + gx
/// 右パネル幅 = 4×kw + 3×gx
/// キーボード高 = 4×kh + 3×gy + 上下余白
/// ```
public struct KeyboardGeometry: Sendable {
    public let containerSize: CGSize
    public let deviceClass: DeviceClass
    public let isSplit: Bool
    /// 実際に適用された倍率（画面に収めるため設定値より小さくなることがある）
    public let appliedScale: CGFloat
    public let keyWidth: CGFloat
    public let keyHeight: CGFloat
    public let gapX: CGFloat
    public let gapY: CGFloat
    public let keyboardHeight: CGFloat
    public let centerGap: CGFloat
    public let panels: [PanelGeometry]

    /// キーが1つも置かれていない領域。ホストはここに文字や候補を出す。
    ///
    /// 分割時は左右パネルに挟まれた中央の縦帯、統合時はキーボードより上の領域。
    public var freeRegion: CGRect {
        guard isSplit,
              let left = panels.first(where: { $0.side == .left }),
              let right = panels.first(where: { $0.side == .right }) else {
            return CGRect(x: 0, y: 0,
                          width: containerSize.width,
                          height: max(0, containerSize.height - keyboardHeight))
        }
        let x = left.frame.maxX + gapX
        let width = max(0, right.frame.minX - gapX - x)
        return CGRect(x: x, y: 0, width: width, height: containerSize.height)
    }

    public func panel(containing keyID: String) -> PanelGeometry? {
        panels.first { panel in panel.keys.contains { $0.id == keyID } }
    }
}

// MARK: - ポップアップの置き場所

public extension KeyboardGeometry {

    /// フリックポップアップは**押したキーの隣ではなく、パネルの内側端に固定する**。
    ///
    /// 隣に開くと、右パネルの さ列 のポップアップが か列・あ列を覆ってしまう。
    /// パネルの外（中央の空き）に固定すれば、どのキーを押してもキーは一切隠れない。
    /// 中央の空きに収まるよう1項目の幅を詰めるので、はみ出すこともない。
    ///
    /// 統合レイアウト（iPhone 縦）には中央の空きがないので、そこだけは従来どおりキーの隣に開き、
    /// 画面外へ出ないようにクランプする。
    func popupPlacement(for key: PlacedKey, itemCount: Int) -> PopupPlacement? {
        guard let panel = panel(containing: key.id) else { return nil }
        return popupPlacement(panel: panel, rect: key.rect, side: key.popupSide, itemCount: itemCount)
    }

    /// 当たり判定の結果から直接引く版。押している指ごとにポップアップを出すのに使う。
    func popupPlacement(for hit: KeyHit, itemCount: Int) -> PopupPlacement? {
        guard let panel = panels.first(where: { $0.id == hit.panelID }) else { return nil }
        return popupPlacement(panel: panel, rect: hit.rect, side: hit.popupSide, itemCount: itemCount)
    }

    private func popupPlacement(panel: PanelGeometry, rect: CGRect, side: PopupSide, itemCount: Int) -> PopupPlacement? {
        guard itemCount > 0 else { return nil }

        let padding = SplitKanaTuning.popupPadding
        let itemHeight = min(keyWidth, keyHeight) * SplitKanaTuning.popupItemRatio

        let available = isSplit
            ? centerGap - gapX * 2
            : containerSize.width - gapX * 2
        let itemWidth = min(
            keyWidth * SplitKanaTuning.popupItemRatio,
            (available - padding * 2) / CGFloat(itemCount)
        )
        guard itemWidth > 0 else { return nil }

        let width = itemWidth * CGFloat(itemCount) + padding * 2
        let height = itemHeight + padding * 2

        let x: CGFloat
        if isSplit {
            // パネルの内側端に固定。キーの位置によらず動かない。
            switch side {
            case .trailing: x = panel.frame.maxX + gapX
            case .leading:  x = panel.frame.minX - gapX - width
            }
        } else {
            let unclamped: CGFloat
            switch side {
            case .trailing: unclamped = panel.frame.minX + rect.maxX + gapX
            case .leading:  unclamped = panel.frame.minX + rect.minX - gapX - width
            }
            x = min(max(unclamped, 0), max(0, containerSize.width - width))
        }

        // 縦はキーの行に合わせるが、パネルの上下からは出さない。
        let desiredY = panel.frame.minY + rect.midY - height / 2
        let y = min(max(desiredY, panel.frame.minY), max(panel.frame.minY, panel.frame.maxY - height))

        return PopupPlacement(
            rect: CGRect(x: x, y: y, width: width, height: height),
            itemWidth: itemWidth,
            itemHeight: itemHeight
        )
    }
}

// MARK: - 組み立て

public extension KeyboardGeometry {

    /// - Parameter deviceClass: 端末クラスを外から指定する。`nil` ならコンテナの縦横比から判定する。
    ///
    ///   **キーボード拡張は必ず指定すること。**拡張のコンテナは「横長で背の低い帯」なので、
    ///   縦横比から向きを判定すると iPhone 横を「縦」と取り違える。
    ///   拡張は画面の向きを知っているので、そちらを渡す。
    static func make(
        containerSize: CGSize,
        safeArea: SafeAreaInsets = .zero,
        isPad: Bool,
        configuration: KeyboardConfiguration,
        deviceClass: DeviceClass? = nil
    ) -> KeyboardGeometry {

        let deviceClass = deviceClass
            ?? DeviceClass.resolve(containerSize: containerSize, isPad: isPad)
        // 設定で上書きできるもの（左右位置・上の余白）はここで差し替えておく。
        let base = deviceClass.baseMetrics.applying(configuration)
        let bottomInset = configuration.bottomInset ?? base.bottomInset
        let requestedScale = configuration.clampedScale

        let usableWidth = containerSize.width - safeArea.leading - safeArea.trailing - base.sideInset * 2
        let usableHeight = containerSize.height - safeArea.bottom - bottomInset - base.topPadding

        // 高さは列構成によらず 4行 + 3ギャップ で決まる。
        let unitHeight = base.keyHeight * 4 + base.gapY * 3
        let heightScale = unitHeight > 0 ? usableHeight / unitHeight : requestedScale

        let rightColumnCount = configuration.showsDuplicateColumn ? 4 : 3

        // まず分割を試す。
        if deviceClass.attemptsSplit {
            // 左パネル 2列（ギャップ1）＋ 右パネル n列（ギャップ n-1）
            let unitWidth = base.keyWidth * CGFloat(2 + rightColumnCount)
                + base.gapX * CGFloat(rightColumnCount)
            let widthScale = unitWidth > 0
                ? (usableWidth - SplitKanaTuning.minimumCenterGap) / unitWidth
                : requestedScale

            // 分割できるかは**横方向の余地だけ**で決める。
            //
            // - ユーザーが小さめの倍率を選んだことは、分割をやめる理由にならない
            //   （requestedScale を混ぜると、小さくしたいだけなのに統合レイアウトへ落ちる）
            // - 高さも理由にならない。分割も統合も4行で、必要な高さは同じ
            //   （heightScale を混ぜると、コンテナをキーボード高ぴったりにしたとき
            //   heightScale が適用倍率そのものに縮み、判定がしきい値の上で揺れる。
            //   キーボード拡張は自分の高さを自分で決めるので、これが実際に起きる）
            if widthScale >= SplitKanaTuning.minimumSplitScale {
                let scale = min(requestedScale, widthScale, heightScale)
                return splitGeometry(
                    containerSize: containerSize,
                    safeArea: safeArea,
                    deviceClass: deviceClass,
                    base: base,
                    bottomInset: bottomInset,
                    scale: scale,
                    rightColumnCount: rightColumnCount,
                    configuration: configuration
                )
            }
        }

        // 分割の余地がない → 標準どおりの5列にフォールバック（SPEC 3.3）。
        let unifiedColumns = 5
        let unitWidth = base.keyWidth * CGFloat(unifiedColumns) + base.gapX * CGFloat(unifiedColumns - 1)
        let widthScale = unitWidth > 0 ? usableWidth / unitWidth : requestedScale
        let scale = min(requestedScale, widthScale, heightScale)

        return unifiedGeometry(
            containerSize: containerSize,
            safeArea: safeArea,
            deviceClass: deviceClass,
            base: base,
            bottomInset: bottomInset,
            scale: scale,
            configuration: configuration
        )
    }

    // MARK: - 分割

    private static func splitGeometry(
        containerSize: CGSize,
        safeArea: SafeAreaInsets,
        deviceClass: DeviceClass,
        base: BaseMetrics,
        bottomInset: CGFloat,
        scale: CGFloat,
        rightColumnCount: Int,
        configuration: KeyboardConfiguration
    ) -> KeyboardGeometry {

        let kw = base.keyWidth * scale
        let kh = base.keyHeight * scale
        let gx = base.gapX * scale
        let gy = base.gapY * scale

        let panelHeight = kh * 4 + gy * 3
        let keyboardHeight = panelHeight + base.topPadding + bottomInset + safeArea.bottom
        let panelY = containerSize.height - keyboardHeight + base.topPadding

        let leftWidth = kw * 2 + gx
        let rightWidth = kw * CGFloat(rightColumnCount) + gx * CGFloat(rightColumnCount - 1)

        let leftX = safeArea.leading + base.sideInset
        let rightX = containerSize.width - safeArea.trailing - base.sideInset - rightWidth

        let leftColumns: [KeyColumn] = [.function, .aColumn]
        let rightColumns: [KeyColumn] = configuration.showsDuplicateColumn
            ? [.aColumn, .kaColumn, .saColumn, .utility]
            : [.kaColumn, .saColumn, .utility]

        let leftPanel = PanelGeometry(
            id: "panel.left",
            side: .left,
            frame: CGRect(x: leftX, y: panelY, width: leftWidth, height: panelHeight),
            keys: place(columns: leftColumns,
                        panelID: "left",
                        kw: kw, kh: kh, gx: gx, gy: gy,
                        panelWidth: leftWidth,
                        duplicateColumnIndices: [],
                        popupSide: { _ in .trailing },
                        configuration: configuration)
        )

        // 複製列は右パネルの先頭列だけ。
        let duplicateIndices: Set<Int> = configuration.showsDuplicateColumn ? [0] : []

        let rightPanel = PanelGeometry(
            id: "panel.right",
            side: .right,
            frame: CGRect(x: rightX, y: panelY, width: rightWidth, height: panelHeight),
            keys: place(columns: rightColumns,
                        panelID: "right",
                        kw: kw, kh: kh, gx: gx, gy: gy,
                        panelWidth: rightWidth,
                        duplicateColumnIndices: duplicateIndices,
                        popupSide: { _ in .leading },
                        configuration: configuration)
        )

        return KeyboardGeometry(
            containerSize: containerSize,
            deviceClass: deviceClass,
            isSplit: true,
            appliedScale: scale,
            keyWidth: kw,
            keyHeight: kh,
            gapX: gx,
            gapY: gy,
            keyboardHeight: keyboardHeight,
            centerGap: max(0, rightX - (leftX + leftWidth)),
            panels: [leftPanel, rightPanel]
        )
    }

    // MARK: - 統合（iPhone 縦フォールバック）

    private static func unifiedGeometry(
        containerSize: CGSize,
        safeArea: SafeAreaInsets,
        deviceClass: DeviceClass,
        base: BaseMetrics,
        bottomInset: CGFloat,
        scale: CGFloat,
        configuration: KeyboardConfiguration
    ) -> KeyboardGeometry {

        let kw = base.keyWidth * scale
        let kh = base.keyHeight * scale
        let gx = base.gapX * scale
        let gy = base.gapY * scale

        let panelHeight = kh * 4 + gy * 3
        let keyboardHeight = panelHeight + base.topPadding + bottomInset + safeArea.bottom
        let panelY = containerSize.height - keyboardHeight + base.topPadding

        let columns: [KeyColumn] = [.function, .aColumn, .kaColumn, .saColumn, .utility]
        let panelWidth = kw * CGFloat(columns.count) + gx * CGFloat(columns.count - 1)
        let panelX = (containerSize.width - panelWidth) / 2

        // 統合レイアウトでは中央の空きがないので、左半分は右へ、右半分は左へ開く。
        let panel = PanelGeometry(
            id: "panel.unified",
            side: .unified,
            frame: CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
            keys: place(columns: columns,
                        panelID: "unified",
                        kw: kw, kh: kh, gx: gx, gy: gy,
                        panelWidth: panelWidth,
                        duplicateColumnIndices: [],
                        popupSide: { rect in rect.midX < panelWidth / 2 ? .trailing : .leading },
                        configuration: configuration)
        )

        return KeyboardGeometry(
            containerSize: containerSize,
            deviceClass: deviceClass,
            isSplit: false,
            appliedScale: scale,
            keyWidth: kw,
            keyHeight: kh,
            gapX: gx,
            gapY: gy,
            keyboardHeight: keyboardHeight,
            centerGap: 0,
            panels: [panel]
        )
    }

    // MARK: - 列の配置

    private static func place(
        columns: [KeyColumn],
        panelID: String,
        kw: CGFloat,
        kh: CGFloat,
        gx: CGFloat,
        gy: CGFloat,
        panelWidth: CGFloat,
        duplicateColumnIndices: Set<Int>,
        popupSide: (CGRect) -> PopupSide,
        configuration: KeyboardConfiguration
    ) -> [PlacedKey] {

        var placed: [PlacedKey] = []

        for (columnIndex, column) in columns.enumerated() {
            let x = CGFloat(columnIndex) * (kw + gx)
            var row = 0

            for key in column.keys(configuration: configuration) {
                let span = max(1, key.rowSpan)
                let y = CGFloat(row) * (kh + gy)
                let height = kh * CGFloat(span) + gy * CGFloat(span - 1)
                let rect = CGRect(x: x, y: y, width: kw, height: height)

                placed.append(PlacedKey(
                    id: "\(panelID).\(column.rawValue).\(row)",
                    key: key,
                    rect: rect,
                    isDuplicate: duplicateColumnIndices.contains(columnIndex),
                    popupSide: popupSide(rect)
                ))
                row += span
            }
        }

        return placed
    }
}
