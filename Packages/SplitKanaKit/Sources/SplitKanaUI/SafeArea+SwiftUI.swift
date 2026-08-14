#if canImport(SwiftUI)
import SwiftUI
import SplitKanaCore
#if canImport(UIKit)
import UIKit
#endif

public extension SafeAreaInsets {
    /// 横画面ではノッチ側に余白が入る。パネル原点はセーフエリア基準で計算する（SPEC 10）。
    init(_ insets: EdgeInsets) {
        self.init(leading: insets.leading, trailing: insets.trailing, bottom: insets.bottom)
    }

    #if canImport(UIKit)
    /// `UIInputViewController` 側から渡す用。
    /// `PrefersRightToLeft = false`（SPEC 4）なので left/right をそのまま leading/trailing に対応させる。
    init(_ insets: UIEdgeInsets) {
        self.init(leading: insets.left, trailing: insets.right, bottom: insets.bottom)
    }
    #endif
}

public enum DeviceIdiom {
    public static var isPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
}
#endif
