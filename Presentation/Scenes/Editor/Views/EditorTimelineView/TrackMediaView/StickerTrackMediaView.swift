//
//  StickerTrackMediaView.swift
//  VideoEditor
//
//  Shows a single left-aligned sticker image inside the clip.

import UIKit

final class StickerTrackMediaView: TrackMediaView {

    private let thumbnailGenerator: ThumbnailGenerating
    private let stickerImageView = UIImageView()

    init(frame: CGRect, clip: MediaClip, layout: TimelineLayoutProvider, thumbnailGenerator: ThumbnailGenerating) {
        self.thumbnailGenerator = thumbnailGenerator
        super.init(frame: frame, clip: clip, layout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupMediaContent() {
        contentView.backgroundColor = TimelineConfiguration.default.stickerTrackColor

        stickerImageView.contentMode = .scaleAspectFit
        stickerImageView.clipsToBounds = true
        stickerImageView.tintColor = .white
        stickerImageView.image = UIImage(systemName: "star.fill")
        contentView.addSubview(stickerImageView)

        loadStickerImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = min(contentView.bounds.height, contentView.bounds.width)
        stickerImageView.frame = CGRect(x: 4, y: (contentView.bounds.height - size) / 2, width: size, height: size)
    }

    private func loadStickerImage() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let side = contentView.bounds.height > 0 ? contentView.bounds.height : 36
            let requestSize = CGSize(width: side, height: side)

            let image = await thumbnailGenerator.thumbnail(for: clip.asset, size: requestSize)
            guard !Task.isCancelled else { return }
            stickerImageView.image = image ?? UIImage(systemName: "star.fill")
        }
    }
}
