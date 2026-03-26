//
//  StickerTrackMediaView.swift
//  VideoEditor
//

import UIKit

final class StickerTrackMediaView: TrackMediaView {
    private let imageView = UIImageView()

    override func setupMediaContent() {
        contentView.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.35)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.image = UIImage(systemName: "face.smiling")
        contentView.addSubview(imageView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds.insetBy(dx: 8, dy: 8)
    }
}
