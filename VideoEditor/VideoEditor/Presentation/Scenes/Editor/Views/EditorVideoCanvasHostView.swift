//
// EditorVideoCanvasHostView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import Foundation
import AVFoundation
import UIKit

// MARK: - Video canvas (player layer = backing layer)

/// Hosts preview video with a backing `AVPlayerLayer` so the video surface resizes in sync
/// with constraint-driven layout animations (unlike a separate sublayer sized from `bounds`,
/// which tracks the model geometry and can jump ahead of the animated frame).
final class EditorVideoCanvasHostView: UIView {

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var videoLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .black
        videoLayer.cornerRadius = 12
        videoLayer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
