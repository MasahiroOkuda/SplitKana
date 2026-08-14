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

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()
        // SPEC 10: 起動が遅いと体感が悪い。ここでは載せるだけで、重い処理をしない。
        installKeyboard()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeightIfNeeded()
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
            onOutput: { [weak self] output in self?.handle(output) },
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
                                   configuration: KeyboardSettings.configuration(for: currentDeviceClass))
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
            configuration: KeyboardSettings.configuration(for: deviceClass),
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

    // MARK: - KeyOutput → textDocumentProxy

    /// **この関数が拡張の本体。**`SplitKanaCore` が出した出力を proxy に落とすだけ。
    private func handle(_ output: KeyOutput) {
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
}
