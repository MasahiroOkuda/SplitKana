import SwiftUI

public struct KeyPalette {
    public var kanaFill: Color
    public var kanaStroke: Color
    public var functionFill: Color
    public var functionStroke: Color
    /// 複製列（SPEC 2.1：淡い青系 #EAF0F4 / 枠 #9FBACB）
    public var duplicateFill: Color
    public var duplicateStroke: Color
    public var pressedFill: Color
    public var label: Color
    public var secondaryLabel: Color
    public var popupFill: Color
    public var popupStroke: Color
    public var popupHighlight: Color
    public var popupLabel: Color

    public static let standard = KeyPalette(
        kanaFill: Color(hex: 0xFFFFFF),
        kanaStroke: Color(hex: 0xC7CCD1),
        functionFill: Color(hex: 0xD6DBE0),
        functionStroke: Color(hex: 0xB6BCC2),
        duplicateFill: Color(hex: 0xEAF0F4),
        duplicateStroke: Color(hex: 0x9FBACB),
        pressedFill: Color(hex: 0xB9C4CC),
        label: Color(hex: 0x1C1C1E),
        secondaryLabel: Color(hex: 0x5A6169),
        popupFill: Color(hex: 0xFFFFFF),
        popupStroke: Color(hex: 0x9FBACB),
        popupHighlight: Color(hex: 0x2E7FB8),
        popupLabel: Color(hex: 0x1C1C1E)
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
