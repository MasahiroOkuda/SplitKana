import SwiftUI

/// フェーズ1の確認用ホスト。**画面に文字が出るだけ**（SPEC 7）。
///
/// キーボード拡張はまだ作らない。ここで1週間毎日打って、
/// 文字/分・削除キーの回数・届かないキーの有無を測る。
@main
struct SplitKanaHostApp: App {
    var body: some Scene {
        WindowGroup {
            HostRootView()
        }
    }
}
