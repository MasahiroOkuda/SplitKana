import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension SafeAreaInsets {
    /// 横画面ではノッチ側に余白が入る。パネル原点はセーフエリア基準で計算する（SPEC 10）。
    init(_ insets: EdgeInsets) {
        self.init(leading: insets.leading, trailing: insets.trailing, bottom: insets.bottom)
    }
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
