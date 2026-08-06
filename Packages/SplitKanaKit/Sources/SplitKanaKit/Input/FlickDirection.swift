import CoreGraphics

/// フリック方向。並び順は SPEC 2.3 の表記順（中央 / 左 / 上 / 右 / 下）。
public enum FlickDirection: String, CaseIterable, Sendable {
    case center
    case left
    case up
    case right
    case down
}

/// 1つのキーに割り当たる5方向の文字。
public struct FlickSet: Equatable, Sendable {
    public let center: String
    public let left: String?
    public let up: String?
    public let right: String?
    public let down: String?

    public init(_ center: String, _ left: String? = nil, _ up: String? = nil, _ right: String? = nil, _ down: String? = nil) {
        self.center = center
        self.left = left
        self.up = up
        self.right = right
        self.down = down
    }

    public subscript(direction: FlickDirection) -> String? {
        switch direction {
        case .center: return center
        case .left: return left
        case .up: return up
        case .right: return right
        case .down: return down
        }
    }

    /// 割り当てのある方向だけを `FlickDirection.allCases` の順で返す。ポップアップの並びに使う。
    public var assigned: [(direction: FlickDirection, character: String)] {
        FlickDirection.allCases.compactMap { direction in
            self[direction].map { (direction, $0) }
        }
    }

    /// 割り当てのない方向へフリックされたら中央に落とす。
    public func character(for direction: FlickDirection) -> String {
        self[direction] ?? center
    }
}
