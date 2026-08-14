import UIKit
import SwiftUI
import SplitKanaCore
import SplitKanaUI

/// キーボード拡張の入口（SPEC 7 フェーズ2）。
///
/// **ここの仕事は2つだけ。**
/// 1. `SplitKanaUI` のキーボードを載せる
/// 2. `KeyOutput` を `textDocumentProxy` に流す
///
/// レイアウト計算も入力判定も `SplitKanaCore` にある。ここには置かない。
final class KeyboardViewController: UIInputViewController {

    private var heightConstraint: NSLayoutConstraint?
    private var hosting: UIHostingController<KeyboardRootView>?

    /// 設定パネルを開いているか。
    private var isShowingSettings = false

    /// かなを打っているか、英数を打っているか。
    private var mode: InputMode = .kana

    /// ⇧ の状態（SPEC 2.6）。
    private enum ShiftState {
        case off
        /// 次の1文字だけ大文字。打ったら消える。
        case oneShot
        /// 固定。もう一度 ⇧ を押すまで大文字のまま。
        case locked
    }

    private var shiftState: ShiftState = .off

    /// 直前に ⇧ を押した時刻。続けて押されたか（＝固定にするか）を見る。
    private var lastShiftTap: Date?

    /// 変換の状態機械。**生成が重いので最初のかな入力まで作らない**（SPEC 10）。
    private var conversion: ConversionController?

    private var conversionSession: ConversionSession {
        conversion?.session ?? .empty
    }

    private func ensureConversion() -> ConversionController {
        if let conversion { return conversion }
        // AzooKeyConverter.candidates(for:) は MainActor.assumeIsolated を使う。
        // キー入力は UIInputViewController 経由でメインスレッド同期に届くので、
        // ここで作って ConversionController 経由で呼ぶかぎりその前提が崩れない。
        let created = ConversionController(converter: AzooKeyConverter())
        conversion = created
        return created
    }

    /// 直前に高さを計算したときの入力。同じなら計算し直さない。
    private var lastHeightInput: HeightInput?

    private struct HeightInput: Equatable {
        let width: CGFloat
        let safeArea: SafeAreaInsets
        let configuration: KeyboardConfiguration
        let deviceClass: DeviceClass
    }

    /// 画面の向きから端末クラスを決める。
    ///
    /// **入力ビューの縦横比からは判定できない。**拡張のビューは横長で背が低いので、
    /// アスペクト比で見ると iPhone 横が「縦」に化ける。
    private var currentDeviceClass: DeviceClass {
        let isPad = DeviceIdiom.isPad
        let orientation = view.window?.windowScene?.interfaceOrientation
        // 取れないうちは画面の寸法で代用する。
        let isLandscape = orientation.map(\.isLandscape)
            ?? (UIScreen.main.bounds.width > UIScreen.main.bounds.height)

        if isPad {
            return isLandscape ? .padLandscape : .padPortrait
        }
        return isLandscape ? .phoneLandscape : .phonePortrait
    }

    /// 保存された設定に、いま打っているモードを重ねたもの。
    ///
    /// **モードと ⇧ は設定として保存しない。**キーボードを開くたびにかなへ戻す。
    /// 前回英数のまま終わったせいで、次に開いたら英字が出る、というのが一番困る。
    private func configuration(for deviceClass: DeviceClass) -> KeyboardConfiguration {
        var configuration = KeyboardSettings.configuration(for: deviceClass)
        configuration.mode = mode
        configuration.isShifted = shiftState != .off
        return configuration
    }

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()
        clearInputAssistant()
        makeBackgroundTransparent()
        // SPEC 10: 起動が遅いと体感が悪い。ここでは載せるだけで、重い処理をしない。
        installKeyboard()
    }

    /// iPad でキーボードの上に出るショートカットバーの項目を空にする。
    ///
    /// 元に戻す・書式などの項目が並ぶが、このキーボードでは使わない。
    /// 縦を専有するだけなので落とす。
    private func clearInputAssistant() {
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
    }

    /// 中央の空きから自分の描画物を全部どけて、下が見えるか試す。
    ///
    /// **SPEC 4 は「背景を透明にできない。下のアプリは見えないし触れない」としている。**
    /// 系がキーボードの矩形の裏に不透明な板を敷くためで、それは外から外せない。
    /// ただし自分側が塗っているぶんは外せるので、そこまではやっておく。
    ///
    /// **触れないほうは動かしようがない。**キーボードの矩形に来たタッチは
    /// 系がこちらへ配るので、下のアプリには届かない。見えたとしても押せはしない。
    private func makeBackgroundTransparent() {
        view.backgroundColor = .clear
        inputView?.backgroundColor = .clear
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeightIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // キーボードが降りると未確定表示は系に残らない。
        // セッションだけ生き残ると、次の打鍵が宙に浮いた marked text を書きに行く。
        conversion?.session = .empty
        // 覚えたことを書き出す。**拡張はここを逃すと殺されて消える。**
        conversion?.persistLearning()
    }

    // MARK: - 組み立て

    private func makeRootView(
        geometry: KeyboardGeometry?,
        configuration: KeyboardConfiguration
    ) -> KeyboardRootView {
        KeyboardRootView(
            geometry: geometry,
            configuration: configuration,
            deviceClass: currentDeviceClass,
            isShowingSettings: isShowingSettings,
            session: conversionSession,
            onOutput: { [weak self] output in self?.handle(output) },
            onSelectCandidate: { [weak self] index in self?.commitCandidate(at: index) },
            onSettingsChanged: { [weak self] in self?.reloadSettings() },
            onCloseSettings: { [weak self] in
                self?.isShowingSettings = false
                self?.reloadSettings()
            }
        )
    }

    /// 設定が変わった／パネルを開閉した。寸法から作り直す。
    ///
    /// `lastHeightInput` を捨てるのは、設定が変われば高さも変わりうるため。
    private func reloadSettings() {
        lastHeightInput = nil
        view.setNeedsLayout()
        updateHeightIfNeeded()
    }

    private func installKeyboard() {
        // レイアウトが決まるまでは描かない。寸法は viewWillLayoutSubviews で入れる。
        let controller = UIHostingController(
            rootView: makeRootView(geometry: nil,
                                   configuration: configuration(for: currentDeviceClass))
        )
        controller.view.backgroundColor = .clear

        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        hosting = controller
    }

    /// 拡張は自分の高さを自分で決める。
    ///
    /// **priority は 999。**`.required` にするとフローティング表示などで制約が衝突し、
    /// レイアウトが壊れる（SPEC 4）。
    private func updateHeightIfNeeded() {
        let width = view.bounds.width
        guard width > 0 else { return }

        let deviceClass = currentDeviceClass
        let input = HeightInput(
            width: width,
            safeArea: SafeAreaInsets(view.safeAreaInsets),
            configuration: configuration(for: deviceClass),
            deviceClass: deviceClass
        )
        guard input != lastHeightInput else { return }
        lastHeightInput = input

        let height = KeyboardRootView.keyboardHeight(
            width: width,
            safeArea: input.safeArea,
            configuration: input.configuration,
            deviceClass: input.deviceClass
        )

        // **描画に使うジオメトリはここで1回だけ作る。**
        // コンテナ高＝キーボード高なので panelY は topPadding に落ち着き、
        // タッチ層がビューの外へ出ることがない。
        // 端末クラスは回転で変わる。ビューを載せ替えず、差し替えるだけでよい。
        hosting?.rootView = makeRootView(
            geometry: KeyboardRootView.layout(
                width: width,
                height: height,
                safeArea: input.safeArea,
                configuration: input.configuration,
                deviceClass: input.deviceClass
            ),
            configuration: input.configuration
        )

        if let heightConstraint {
            heightConstraint.constant = height
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: height)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    // MARK: - KeyOutput → 変換 → textDocumentProxy

    /// キーボードからの出力。まず変換に通し、出てきた効果を proxy に落とす。
    private func handle(_ output: KeyOutput) {
        // モードと ⇧ は**変換に通さない**。通すと `.passthrough` で戻ってくるだけで、
        // その間に未確定を確定させる機会を逃す。
        switch output {
        case KeyboardConfiguration.nextModeOutput:
            switchMode(to: mode.next)
            return
        case KeyboardConfiguration.shiftOutput:
            toggleShift()
            return
        default:
            break
        }

        // かな以外は変換に通さない。英字も数字も、仮名漢字変換にかけても意味がない。
        if mode != .kana {
            apply(output)
            consumeShift(after: output)
            return
        }

        // 変換を切れるようにしてあるのは保険。Mac を返した後で変換が重い・
        // 感触が悪いと分かっても、ここで切れば素のかな入力に戻せる。
        // **`ensureConversion()` を通さない。**辞書を読み込ませないことが目的なので。
        guard KeyboardSettings.conversionEnabled(currentDeviceClass) else {
            // 変換中に切られた場合、未確定表示が取り残されるので先に消す。
            if conversion?.session.isComposing == true {
                clearMarkedText()
                conversion?.session = .empty
            }
            apply(output)
            refreshRootView()
            return
        }

        var controller = ensureConversion()
        let effects = controller.handle(output)
        conversion = controller

        apply(effects)

        // 候補の表示を更新する。
        refreshRootView()
    }

    /// 変換が出した効果を proxy に落とす。
    ///
    /// キーからの入力もタップ確定もここを通る。**確定の経路は1つに保つ。**
    private func apply(_ effects: [ConversionEffect]) {
        for effect in effects {
            switch effect {
            case .markedText(let text):
                textDocumentProxy.setMarkedText(
                    text, selectedRange: NSRange(location: text.utf16.count, length: 0))

            case .commit(let text):
                // unmarkText() は未確定を捨てるのではなく確定させる。
                // 先に空にしておかないと、この直後の insertText と合わせて二重に入る。
                clearMarkedText()
                textDocumentProxy.insertText(text)

            case .clear:
                clearMarkedText()

            case .passthrough(let output):
                apply(output)
            }
        }
    }

    /// 未確定表示を消す。
    ///
    /// `unmarkText()` だけでは**確定してしまう**ので、先に空文字で置き換える。
    private func clearMarkedText() {
        textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        textDocumentProxy.unmarkText()
    }

    /// 候補欄がタップされた。その候補で確定する。
    ///
    /// **キーで確定したときと同じ経路を通す。**確定の扱いが二通りあると、
    /// 学習や後処理を足したときに片方だけ漏れる。
    private func commitCandidate(at index: Int) {
        guard var controller = conversion else { return }
        let effects = controller.commitCandidate(at: index)
        conversion = controller
        guard !effects.isEmpty else { return }
        apply(effects)
        refreshRootView()
    }

    // MARK: - かな／英数

    /// モードを切り替える。
    ///
    /// **切り替える前に未確定を確定させる。**残したまま配列を入れ替えると、
    /// 未確定の読みがどのキーにも紐付かないまま画面に残る。
    private func switchMode(to newMode: InputMode) {
        guard mode != newMode else { return }
        if let conversion, conversion.session.isComposing {
            commitCandidate(at: conversion.session.selection)
        }
        mode = newMode
        // モードをまたいで ⇧ を持ち越さない。
        shiftState = .off
        lastShiftTap = nil
        reloadSettings()
    }

    /// ⇧。1回で次の1文字だけ、続けて2回で固定（SPEC 2.6）。
    ///
    /// 固定を別キーにする余地が無いので、間隔で見分ける。
    private func toggleShift() {
        let now = Date()
        let isRepeatTap = lastShiftTap.map {
            now.timeIntervalSince($0) < SplitKanaTuning.shiftLockInterval
        } ?? false
        lastShiftTap = now

        switch shiftState {
        case .off:
            shiftState = .oneShot
        case .oneShot:
            // 続けて押したなら固定。間を空けて押したなら「やっぱりやめる」。
            shiftState = isRepeatTap ? .locked : .off
        case .locked:
            shiftState = .off
        }
        reloadSettings()
    }

    /// 大文字を1文字打ったら ⇧ を落とす。固定中は落とさない。
    private func consumeShift(after output: KeyOutput) {
        guard shiftState == .oneShot, case .insert = output else { return }
        shiftState = .off
        reloadSettings()
    }

    /// 変換に関係ない出力を proxy に流す。
    private func apply(_ output: KeyOutput) {
        let proxy = textDocumentProxy
        switch output {
        case .insert(let text):
            proxy.insertText(text)

        case .backspace:
            proxy.deleteBackward()

        case .space:
            proxy.insertText(" ")

        case .newline:
            proxy.insertText("\n")

        case .dakuten:
            // 直前1文字を巡回させる（SPEC 2.4）。巡回対象でなければ何もしない。
            guard let before = proxy.documentContextBeforeInput,
                  let cycled = DakutenCycle.cyclingLastCharacter(of: before) else { return }
            proxy.deleteBackward()
            proxy.insertText(String(cycled))

        case .cursor(let offset):
            proxy.adjustTextPosition(byCharacterOffset: offset)

        case .candidate:
            // 変換を切っているときはここに来る。空白キーの左フリックなので全角スペース。
            // 握り潰すと、いちばん多く打つキーで打鍵が無音で消える。
            proxy.insertText(SplitKanaTuning.fullWidthSpace)

        case .nextInputMode:
            // 地球キー。これが無いと他のキーボードに戻れない（SPEC 2.2）。
            advanceToNextInputMode()

        case KeyboardConfiguration.settingsOutput:
            // 拡張は別画面を出せないので、キーボードの中でパネルを開閉する（SPEC 4）。
            isShowingSettings.toggle()
            reloadSettings()

        case .custom:
            break
        }
    }

    /// 候補表示だけを更新する。寸法は変わらないので作り直さない。
    private func refreshRootView() {
        guard let geometry = hosting?.rootView.geometry else { return }
        hosting?.rootView = makeRootView(
            geometry: geometry,
            configuration: configuration(for: currentDeviceClass)
        )
    }
}
