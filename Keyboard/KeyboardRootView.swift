import SwiftUI
import SplitKanaCore
import SplitKanaUI

/// 拡張に載せる SwiftUI のいちばん外側。
///
/// **ジオメトリはここで計算しない。`KeyboardViewController` が計算したものを受け取る。**
///
/// 以前はここでも `GeometryReader` から計算し直していたが、
/// VC 側（`view.safeAreaInsets`）と SwiftUI 側（`proxy.safeAreaInsets`）がズレると
/// `panelY = containerHeight - keyboardHeight + topPadding` が負に振れ、
/// タッチ層がビューの外に出る。SwiftUI はクリップしないので**描画は正しいまま、
/// UIKit のヒットテストだけが祖先ビューの外側を弾いてキーが反応しなくなる。**
/// 計算箇所を1つにすれば、この破綻はそもそも起きない。
struct KeyboardRootView: View {

    /// レイアウト確定前は nil。何も描かない。
    let geometry: KeyboardGeometry?
    let configuration: KeyboardConfiguration
    let deviceClass: DeviceClass
    let isShowingSettings: Bool
    let session: ConversionSession
    let onOutput: (KeyOutput) -> Void
    /// 設定が変わった。呼び出し側が読み直して再レイアウトする。
    let onSettingsChanged: () -> Void
    let onCloseSettings: () -> Void

    var body: some View {
        if let geometry {
            ZStack(alignment: .topLeading) {
                SplitKanaKeyboardView(
                    geometry: geometry,
                    configuration: configuration,
                    touchArea: touchArea(for: geometry),
                    onOutput: onOutput
                )

                // 設定パネルとは排他。⚙ を開いている間は候補を出さない。
                if session.isComposing, !isShowingSettings {
                    CandidateBarView(session: session, region: candidateRegion(for: geometry))
                }

                if isShowingSettings {
                    KeyboardSettingsPanel(
                        region: settingsRegion(for: geometry),
                        deviceClass: deviceClass,
                        appliedScale: geometry.appliedScale,
                        // 統合レイアウトではキーの上に重なるので、背景を透かさない。
                        isOpaque: !geometry.isSplit,
                        onChange: onSettingsChanged,
                        onClose: onCloseSettings
                    )
                }
            }
        } else {
            Color.clear
        }
    }

    /// 設定パネルを開いている間のタッチ板の敷き方。
    ///
    /// - 分割時：中央の空きにパネルが開くのでキーとは重ならない。
    ///   ただし全面に敷いたままだとスライダーが触れないので、パネルの上だけに敷く
    /// - 統合時（iPhone 縦）：中央の空きが無く、パネルがキーに重なる。
    ///   タッチ板は本物の `UIView` なので、重ねただけでは触らせられない。降ろす
    private func touchArea(for geometry: KeyboardGeometry) -> SplitKanaKeyboardView.TouchArea {
        guard isShowingSettings else { return .container }
        return geometry.isSplit ? .panels : .none
    }

    /// パネルを置く矩形。
    ///
    /// 分割時は中央の空き。統合時は中央が無いのでキーボード全面に重ねる。
    /// **iPhone 縦でも調整できないと、Mac を返したあと縦画面だけ直せなくなる。**
    private func settingsRegion(for geometry: KeyboardGeometry) -> CGRect {
        let region = geometry.isSplit
            ? geometry.freeRegion
            : CGRect(origin: .zero, size: geometry.containerSize)
        return region.insetBy(dx: 6, dy: 6)
    }

    /// 候補バーの置き場所。分割時は中央の空きの上寄り、統合時はキーボード上端。
    ///
    /// 高さはバー側が決める。読み・現在地・前後の予告を積むので、
    /// ここで決め打ちにするとバーの中身と食い違う。
    private func candidateRegion(for geometry: KeyboardGeometry) -> CGRect {
        let region = geometry.isSplit
            ? geometry.freeRegion
            : CGRect(origin: .zero, size: geometry.containerSize)
        return CGRect(x: region.minX + 6, y: region.minY + 6,
                      width: max(0, region.width - 12),
                      height: CandidateBarView.preferredHeight)
    }
}

extension KeyboardRootView {

    /// 高さ側で頭打ちにならないよう、計算用に渡す十分大きな値。
    private static let unboundedHeight: CGFloat = 4000

    /// 拡張が自分の高さを決めるための計算。
    ///
    /// キーボード高は幅と倍率から決まるので、**高さに上限を与えずに1回計算して**その結果を使う。
    /// この値をコンテナ高として `layout(...)` に渡すと `panelY` は `topPadding` に落ち着く。
    static func keyboardHeight(
        width: CGFloat,
        safeArea: SafeAreaInsets,
        configuration: KeyboardConfiguration,
        deviceClass: DeviceClass
    ) -> CGFloat {
        KeyboardGeometry.make(
            containerSize: CGSize(width: width, height: unboundedHeight),
            safeArea: safeArea,
            isPad: DeviceIdiom.isPad,
            configuration: configuration,
            deviceClass: deviceClass
        ).keyboardHeight
    }

    /// 実際に描くジオメトリ。**コンテナ高はキーボード高そのもの。**
    static func layout(
        width: CGFloat,
        height: CGFloat,
        safeArea: SafeAreaInsets,
        configuration: KeyboardConfiguration,
        deviceClass: DeviceClass
    ) -> KeyboardGeometry {
        KeyboardGeometry.make(
            containerSize: CGSize(width: width, height: height),
            safeArea: safeArea,
            isPad: DeviceIdiom.isPad,
            configuration: configuration,
            deviceClass: deviceClass
        )
    }
}
