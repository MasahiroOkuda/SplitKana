import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// 当たったキーと、それが属するパネル。
public struct KeyHit: Equatable, Sendable {
    public let panelID: String
    public let keyID: String
    public let key: KeyDescriptor
    public let popupSide: PopupSide
    /// パネル内座標での見た目の矩形
    public let rect: CGRect
}

public extension KeyboardGeometry {

    /// コンテナ座標の1点から、押されたキーを引く。
    ///
    /// **ビューの重なりではなく計算済みの矩形で判定する。**
    /// こうしておくと、指ごとに独立して当たりを取れるので同時押しが素直に書ける。
    ///
    /// タップ領域は見た目のキーより上下左右 `touchOutset` だけ広い（SPEC 10）。
    /// 広げた縁どうしが重なった場合だけ、中心が近いほうを採る。
    func hitTest(_ point: CGPoint) -> KeyHit? {
        let outset = SplitKanaTuning.touchOutset
        var fallback: (hit: KeyHit, distance: CGFloat)?

        for panel in panels {
            let x = point.x - panel.frame.minX
            let y = point.y - panel.frame.minY

            for placed in panel.keys {
                let r = placed.rect
                guard x >= r.minX - outset, x <= r.maxX + outset,
                      y >= r.minY - outset, y <= r.maxY + outset else { continue }

                let hit = KeyHit(panelID: panel.id, keyID: placed.id, key: placed.key,
                                 popupSide: placed.popupSide, rect: r)

                // 見た目の矩形の内側なら、そこで決まり。
                if x >= r.minX, x <= r.maxX, y >= r.minY, y <= r.maxY { return hit }

                let dx = x - (r.minX + r.width / 2)
                let dy = y - (r.minY + r.height / 2)
                let d = dx * dx + dy * dy
                if fallback == nil || d < fallback!.distance { fallback = (hit, d) }
            }
        }
        return fallback?.hit
    }
}
