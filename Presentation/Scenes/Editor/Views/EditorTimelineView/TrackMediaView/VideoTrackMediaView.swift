//
//  VideoTrackMediaView.swift
//  VideoEditor
//

import UIKit
import AVFoundation

final class VideoTrackMediaView: TrackMediaView {
    private let imageView = UIImageView()
    private let thumbnailGenerator: ThumbnailGenerating

    init (frame: CGRect, clip: MediaClip, pixelsPerSecond: CGFloat, thumbnailGenerator: ThumbnailGenerating) {
        self.thumbnailGenerator = thumbnailGenerator
        super.init(frame: frame, clip: clip, pixelsPerSecond: pixelsPerSecond)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setupMediaContent() {
        contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.image = UIImage(systemName: "video.fill")
        imageView.tintColor = .white
        contentView.addSubview(imageView)
        loadThumbnailIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
    }

    private func loadThumbnailIfNeeded() {
        guard clip.asset.mediaType == .video else { return }
        
        Task { @MainActor [weak self] in
            guard let self else { return }

            // Defer size resolution until layout has occurred; fall back to a
            // reasonable default if the cell hasn't been laid out yet.
            let bounds = imageView.bounds
            let scale  = UIScreen.main.scale
            let size   = bounds.width > 0
                ? CGSize(width: bounds.width * scale, height: bounds.height * scale)
                : CGSize(width: 120, height: 120)

            let image = await thumbnailGenerator.thumbnail(for: clip.asset, size: size)
            guard !Task.isCancelled else { return }

            if let image {
                imageView.image = image
            }
        }
    }
}
