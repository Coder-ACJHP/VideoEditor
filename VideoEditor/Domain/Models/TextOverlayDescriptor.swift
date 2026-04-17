//
// TextOverlayDescriptor
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Editable text content (position/scale/rotation live on `MediaClip.transform`).
//  Editor sessions use `TextOverlayItem` (timeline + descriptor + transform) as the logical row type.
//  `fontSize` is defined for a 1080p-tall reference; preview/export scale to the real canvas height.

import CoreGraphics
import Foundation

nonisolated struct TextOverlayDescriptor: Codable, Equatable, Hashable, Sendable {

    var text: String
    var fontName: String
    /// Point size at the 1080p-tall reference frame (see `TextOverlayRenderingService`).
    var fontSize: CGFloat
    var textColorHex: String
    var backgroundColorHex: String?
    /// Line alignment; prefer `.natural` for RTL languages.
    var alignmentMode: TextOverlayTextAlignment

    // MARK: - Codable (CGFloat / iOS 16–safe)

    enum CodingKeys: String, CodingKey {
        case text
        case fontName
        case fontSize
        case textColorHex
        case backgroundColorHex
        case alignmentMode
    }

    init(
        text: String,
        fontName: String,
        fontSize: CGFloat,
        textColorHex: String,
        backgroundColorHex: String? = nil,
        alignmentMode: TextOverlayTextAlignment = .natural
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.alignmentMode = alignmentMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        fontName = try c.decode(String.self, forKey: .fontName)
        fontSize = CGFloat(try c.decode(Double.self, forKey: .fontSize))
        textColorHex = try c.decode(String.self, forKey: .textColorHex)
        backgroundColorHex = try c.decodeIfPresent(String.self, forKey: .backgroundColorHex)
        alignmentMode = try c.decodeIfPresent(TextOverlayTextAlignment.self, forKey: .alignmentMode) ?? .natural
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(text, forKey: .text)
        try c.encode(fontName, forKey: .fontName)
        try c.encode(Double(fontSize), forKey: .fontSize)
        try c.encode(textColorHex, forKey: .textColorHex)
        try c.encodeIfPresent(backgroundColorHex, forKey: .backgroundColorHex)
        try c.encode(alignmentMode, forKey: .alignmentMode)
    }

    /// Default descriptor for a new text clip (editor / preview).
    static func defaultNew(text: String = "Sample Text") -> TextOverlayDescriptor {
        TextOverlayDescriptor(
            text: text,
            fontName: "HelveticaNeue-Bold",
            fontSize: 48,
            textColorHex: "#FFFFFF",
            backgroundColorHex: nil,
            alignmentMode: .natural
        )
    }
}
