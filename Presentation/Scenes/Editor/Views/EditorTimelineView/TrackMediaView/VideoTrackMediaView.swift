//
//  VideoTrackMediaView.swift
//  VideoEditor
//
//  Requests per-second thumbnails via ThumbnailGenerating and tiles them
//  horizontally across the clip width. Each tile represents ~1 second of footage.

import UIKit

final class VideoTrackMediaView: TrackMediaView {

    private let thumbnailGenerator: ThumbnailGenerating
    private var tileImageViews: [UIImageView] = []

    init(frame: CGRect, clip: MediaClip, pixelsPerSecond: CGFloat, thumbnailGenerator: ThumbnailGenerating) {
        self.thumbnailGenerator = thumbnailGenerator
        super.init(frame: frame, clip: clip, pixelsPerSecond: pixelsPerSecond)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupMediaContent() {
        contentView.backgroundColor = TimelineConfiguration.default.videoTrackColor
        rebuildTiles()
        loadThumbnails()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTiles()
    }

    // MARK: - Tiling

    private var tileWidth: CGFloat {
        pixelsPerSecond
    }

    private var neededTileCount: Int {
        max(Int(ceil(contentView.bounds.width / max(tileWidth, 1))), 1)
    }

    private func rebuildTiles() {
        tileImageViews.forEach { $0.removeFromSuperview() }
        tileImageViews.removeAll()

        for _ in 0..<neededTileCount {
            let iv = makeTileImageView()
            contentView.addSubview(iv)
            tileImageViews.append(iv)
        }
        layoutTiles()
    }

    private func layoutTiles() {
        let count = neededTileCount
        syncTileViewCount(to: count)

        let w = tileWidth
        let h = contentView.bounds.height
        for (i, tile) in tileImageViews.enumerated() {
            tile.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
        }
    }

    private func syncTileViewCount(to count: Int) {
        while tileImageViews.count < count {
            let iv = makeTileImageView()
            contentView.addSubview(iv)
            tileImageViews.append(iv)
        }
        while tileImageViews.count > count {
            tileImageViews.removeLast().removeFromSuperview()
        }
    }

    private func makeTileImageView() -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = TimelineConfiguration.default.videoTilePlaceholderColor
        iv.image = UIImage(systemName: "video.fill")
        iv.tintColor = .white.withAlphaComponent(0.3)
        return iv
    }

    // MARK: - Thumbnail Loading

    private func loadThumbnails() {
        guard clip.asset.mediaType == .video else { return }

        let duration = clip.timelineRange.durationSeconds
        let count = max(Int(ceil(duration)), 1)
        let tileHeight = contentView.bounds.height > 0 ? contentView.bounds.height : 60
        let scale = UIScreen.main.scale
        let requestSize = CGSize(width: tileWidth * scale, height: tileHeight * scale)

        for i in 0..<count {
            let timeSeconds = Double(i) + 0.5
            let tileIndex = i

            Task { @MainActor [weak self] in
                guard let self, tileIndex < self.tileImageViews.count else { return }
                let image = await thumbnailGenerator.videoFrame(
                    for: clip.asset,
                    at: timeSeconds,
                    size: requestSize
                )
                guard !Task.isCancelled, tileIndex < self.tileImageViews.count else { return }
                if let image {
                    self.tileImageViews[tileIndex].image = image
                }
            }
        }
    }
}
