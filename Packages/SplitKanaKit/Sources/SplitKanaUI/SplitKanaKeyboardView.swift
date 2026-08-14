#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import SplitKanaCore

/// 分割かなキーボード本体。
///
/// このビューは**コンテナ全面**を占める。左右のパネルは計算済みの矩形に絶対配置され、
/// 中央（`geometry.freeRegion`）には何も置かない。ホストがそこを自由に使う。
///
/// **両手の親指の同時押しに対応している。**キーはタッチを受け取らず、
/// パネルごとに敷いた `MultiTouchOverlay` が生のタッチを指ごとに流し、
/// `KeyboardGeometry.hitTest` が当たりを決める。
/// タッチ判定をビューの重なりから切り離してあるので、指の数だけ独立して解ける。
///
/// `KeyOutput` を出すだけで、テキストがどこへ行くかは知らない（SPEC 1）。
public struct SplitKanaKeyboardView: View {

    private struct Finger {
        let start: CGPoint
        let hit: KeyHit
        var direction: FlickDirection
    }

    private let geometry: KeyboardGeometry
    private let configuration: KeyboardConfiguration
    private let palette: KeyPalette
    private let onOutput: (KeyOutput) -> Void
    private let touchArea: TouchArea

    /// タッチを受ける板の敷き方。
    public enum TouchArea: Sendable {
        /// パネルの上だけに敷く。中央はホストのもの（確認用ホストの文字表示や設定パネル）。
        case panels
        /// コンテナ全面に1枚だけ敷く。**キーボード拡張の通常時はこちら。**
        /// 拡張の中央は自分の領域なので塞いで構わないし、
        /// `.offset` を使わないぶんヒットテストの取りこぼしが起きない。
        case container
        /// 敷かない。キーは反応しなくなる。
        ///
        /// **キーの上に何かを重ねるときに使う。**タッチ板は本物の `UIView` なので、
        /// SwiftUI で上に重ねただけでは UIKit の重なり順で負けてタッチを奪われうる。
        /// 重ねる側を確実に触らせたいなら、こちらで降ろすのが確実。
        case none
    }

    @State private var fingers: [ObjectIdentifier: Finger] = [:]

    /// 押しっぱなしで走らせる連続入力。**キーボード全体で1本だけ。**
    /// ⌫ を押しながらカーソルもフリックし続ける、という持ち方は無いので、
    /// 後から始めたほうが前のを引き継ぐ。
    private struct Repeating {
        let finger: ObjectIdentifier
        /// いま繰り返している出力。フリックの向きを変えるとこれが変わる。
        let output: KeyOutput
        let task: Task<Void, Never>
    }

    /// ⌫ の長押しと、カーソルキーのフリック維持で走る。
    @State private var repeating: Repeating?
    /// 連続入力が1回でも走った指。走ったなら離したときの1回を出さない
    /// （連続ぶんで足りている）。
    ///
    /// **指ごとに持つ。**両手の親指が同時に動くので、1つの旗にすると
    /// 片方の ⌫ 長押しがもう片方の打鍵を飲み込む。
    @State private var didRepeat: Set<ObjectIdentifier> = []

    public init(
        geometry: KeyboardGeometry,
        configuration: KeyboardConfiguration,
        palette: KeyPalette = .standard,
        touchArea: TouchArea = .panels,
        onOutput: @escaping (KeyOutput) -> Void
    ) {
        self.geometry = geometry
        self.configuration = configuration
        self.palette = palette
        self.touchArea = touchArea
        self.onOutput = onOutput
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // **これが無いと ZStack はいちばん大きい子の寸法にしかならない。**
            // `.offset` はレイアウト寸法に影響しないので、その外へ出した子は
            // 描画はされる（クリップされない）のに、UIKit のヒットテストが通らず
            // タッチだけが死ぬ。コンテナ全面を占める透明な子で寸法を固定する。
            Color.clear
                .frame(width: geometry.containerSize.width,
                       height: geometry.containerSize.height)
                .allowsHitTesting(false)

            ForEach(geometry.panels) { panel in
                panelView(panel)
                    .frame(width: panel.frame.width, height: panel.frame.height)
                    .offset(x: panel.frame.minX, y: panel.frame.minY)
            }
            // ポップアップはパネルより上のレイヤに描く。
            // パネルの外側に固定されるので、どのキーにも重ならない。
            popupLayer
            touchLayer
        }
        .frame(width: geometry.containerSize.width,
               height: geometry.containerSize.height,
               alignment: .topLeading)
    }

    private func panelView(_ panel: PanelGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(panel.keys) { placed in
                KeyView(
                    placed: placed,
                    palette: palette,
                    pressedDirection: direction(forKey: placed.id)
                )
            }
        }
    }

    /// パネルごとに1つ。同じパネルを2本の指で押すことは想定しない（親指は片側に1本）。
    @ViewBuilder
    private var popupLayer: some View {
        ForEach(geometry.panels) { panel in
            if let finger = fingers.values.first(where: {
                   $0.hit.panelID == panel.id && $0.hit.key.kind.flickSet != nil
               }),
               let flickSet = finger.hit.key.kind.flickSet,
               let placement = geometry.popupPlacement(for: finger.hit) {
                FlickPopupView(
                    flickSet: flickSet,
                    selected: finger.direction,
                    itemWidth: placement.itemWidth,
                    itemHeight: placement.itemHeight,
                    palette: palette
                )
                .frame(width: placement.rect.width, height: placement.rect.height)
                .offset(x: placement.rect.minX, y: placement.rect.minY)
                .allowsHitTesting(false)
            }
        }
    }

    /// パネルの上だけに敷く。中央の空きはホストのものなので塞がない。
    ///
    /// **コンテナの外へ出さない。**はみ出した部分は SwiftUI ではそのまま描かれるが、
    /// UIKit のヒットテストは祖先ビューの外側を弾くため、
    /// 見た目は正しいのにタッチだけ死ぬ、という形で壊れる。
    private var touchLayer: some View {
        let outset = SplitKanaTuning.touchOutset
        let container = CGRect(origin: .zero, size: geometry.containerSize)

        let rects: [(String, CGRect)]
        switch touchArea {
        case .container:
            // 1枚で全面を覆う。**`.offset` を一切使わない。**
            // どのキーかは `hitTest` が決め、パネルの外は nil になるので実害がない。
            rects = [("all", container)]
        case .panels:
            rects = geometry.panels.map {
                ($0.id, $0.frame.insetBy(dx: -outset, dy: -outset).intersection(container))
            }
        case .none:
            rects = []
        }

        return ForEach(rects, id: \.0) { _, rect in
            MultiTouchOverlay { phase, id, local in
                handle(phase, id, CGPoint(x: rect.minX + local.x,
                                          y: rect.minY + local.y))
            }
            .frame(width: rect.width, height: rect.height)
            // 中身が透明なので、これが無いと当たり判定の形が空になりうる。
            .contentShape(Rectangle())
            .offset(x: rect.minX, y: rect.minY)
        }
    }

    // MARK: - タッチ

    private func direction(forKey id: String) -> FlickDirection? {
        fingers.values.first { $0.hit.keyID == id }?.direction
    }

    private func handle(_ phase: MultiTouchOverlay.Phase, _ id: ObjectIdentifier, _ point: CGPoint) {
        switch phase {
        case .began:
            guard let hit = geometry.hitTest(point) else { return }
            let finger = Finger(start: point, hit: hit, direction: .center)
            fingers[id] = finger
            didRepeat.remove(id)
            syncRepeat(finger, for: id)

        case .moved:
            guard var finger = fingers[id] else { return }
            finger.direction = FlickResolver.direction(
                translation: CGSize(width: point.x - finger.start.x,
                                    height: point.y - finger.start.y),
                threshold: configuration.flickThreshold
            )
            fingers[id] = finger
            // フリックの向きが変われば、繰り返す中身も変わる。
            syncRepeat(finger, for: id)

        case .ended:
            let repeated = stopRepeating(for: id)
            guard let finger = fingers.removeValue(forKey: id) else { return }
            // 連続入力が走ったなら、離したときの1回は出さない。
            guard !repeated else { return }
            emit(finger)

        case .cancelled:
            _ = stopRepeating(for: id)
            fingers.removeValue(forKey: id)
        }
    }

    /// いまの指の状態に合わせて連続入力を張り直す。
    private func syncRepeat(_ finger: Finger, for id: ObjectIdentifier) {
        let output = finger.hit.key.kind.output(for: finger.direction)

        guard output.repeatsWhileHeld else {
            // ⌫ から指が外れた、フリックを中央へ戻した、など。
            cancelRepeatTask(for: id)
            return
        }
        // 同じものを繰り返している最中なら、間隔を仕切り直さない。
        guard repeating?.finger != id || repeating?.output != output else { return }
        startRepeating(output, for: id)
    }

    /// 少し待ってから繰り返しを始める。
    ///
    /// 待たずに走らせると、1文字消すつもりの短い押下や、
    /// 1つ動かすつもりのフリックでも走り出してしまう。
    private func startRepeating(_ output: KeyOutput, for id: ObjectIdentifier) {
        repeating?.task.cancel()
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(SplitKanaTuning.repeatDelay))
            while !Task.isCancelled {
                didRepeat.insert(id)
                onOutput(output)
                try? await Task.sleep(for: .seconds(SplitKanaTuning.repeatInterval))
            }
        }
        repeating = Repeating(finger: id, output: output, task: task)
    }

    /// 走っているものを止める。**`didRepeat` は消さない。**
    /// 向きを変えただけのときに、走った事実まで消えると離したときの1回が余分に出る。
    private func cancelRepeatTask(for id: ObjectIdentifier) {
        guard let repeating, repeating.finger == id else { return }
        repeating.task.cancel()
        self.repeating = nil
    }

    /// 指を離した。連続入力を止め、**その指で走っていたかどうかを返す。**
    private func stopRepeating(for id: ObjectIdentifier) -> Bool {
        cancelRepeatTask(for: id)
        return didRepeat.remove(id) != nil
    }

    private func emit(_ finger: Finger) {
        onOutput(finger.hit.key.kind.output(for: finger.direction))
    }
}

/// コンテナ寸法を自分で測る版。キーボード拡張（フェーズ2）はこちらを使う想定。
public struct AutoSplitKanaKeyboardView: View {

    private let configuration: KeyboardConfiguration
    private let palette: KeyPalette
    private let onOutput: (KeyOutput) -> Void

    public init(
        configuration: KeyboardConfiguration,
        palette: KeyPalette = .standard,
        onOutput: @escaping (KeyOutput) -> Void
    ) {
        self.configuration = configuration
        self.palette = palette
        self.onOutput = onOutput
    }

    public var body: some View {
        GeometryReader { proxy in
            let geometry = KeyboardGeometry.make(
                containerSize: proxy.size,
                safeArea: SafeAreaInsets(proxy.safeAreaInsets),
                isPad: DeviceIdiom.isPad,
                configuration: configuration
            )
            SplitKanaKeyboardView(
                geometry: geometry,
                configuration: configuration,
                palette: palette,
                onOutput: onOutput
            )
        }
    }
}
#endif
