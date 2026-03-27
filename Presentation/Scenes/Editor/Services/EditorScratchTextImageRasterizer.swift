//
//  EditorScratchTextImageRasterizer.swift
//  VideoEditor
//
//  Temporary PNG generation for overlay/text prototyping — UIKit lives here, not in the ViewModel.
//

import UIKit

protocol EditorScratchTextImageRasterizing {
    /// Writes a PNG into a unique file under the temporary directory.
    @MainActor
    func makeTemporaryPNGURL(text: String) throws -> URL
}

struct EditorScratchTextImageRasterizer: EditorScratchTextImageRasterizing {

    nonisolated init() {}

    @MainActor
    func makeTemporaryPNGURL(text: String) throws -> URL {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 720, height: 220), format: rendererFormat)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]

            let textRect = CGRect(x: 24, y: 40, width: 672, height: 140)
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }

        guard let data = image.pngData() else {
            throw RasterError.pngEncodingFailed
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-text-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try data.write(to: url, options: .atomic)
        return url
    }

    enum RasterError: Error {
        case pngEncodingFailed
    }
}

