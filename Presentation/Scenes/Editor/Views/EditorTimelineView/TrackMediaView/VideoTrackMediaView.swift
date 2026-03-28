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
    private var thumbnailLoadTask: Task<Void, Never>?
    private var lastThumbnailLoadKey: String?

    init(frame: CGRect, clip: MediaClip, layout: TimelineLayoutProvider, thumbnailGenerator: ThumbnailGenerating) {
        self.thumbnailGenerator = thumbnailGenerator
        super.init(frame: frame, clip: clip, layout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            thumbnailLoadTask?.cancel()
            thumbnailLoadTask = nil
        }
    }

    override func setupMediaContent() {
        contentView.backgroundColor = TimelineConfiguration.default.videoTrackColor
        rebuildTiles()
        scheduleThumbnailLoadIfNeeded(force: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTiles()
        scheduleThumbnailLoadIfNeeded(force: false)
    }

    override func didFinishTrimming() {
        lastThumbnailLoadKey = nil
        rebuildTiles()
        scheduleThumbnailLoadIfNeeded(force: true)
    }

    // MARK: - Tiling

    private var tileWidth: CGFloat {
        layout.pointsPerSecond
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

    /// One load pass per unique layout + trim; avoids N = full duration in seconds (hundreds of parallel decodes).
    private func scheduleThumbnailLoadIfNeeded(force: Bool) {
        guard clip.asset.mediaType == .video else { return }
        guard contentView.bounds.width > 0, !tileImageViews.isEmpty else { return }

        let key = thumbnailLoadKey
        if !force, key == lastThumbnailLoadKey { return }
        lastThumbnailLoadKey = key
        loadThumbnails()
    }

    private var thumbnailLoadKey: String {
        let h = contentView.bounds.height
        return "\(contentView.bounds.width)_\(tileImageViews.count)_\(sourceRange.startSeconds)_\(sourceRange.durationSeconds)_\(layout.pointsPerSecond)_\(h)"
    }

    private func loadThumbnails() {
        guard clip.asset.mediaType == .video else { return }

        thumbnailLoadTask?.cancel()

        let n = tileImageViews.count
        guard n > 0 else { return }

        let tileHeight = contentView.bounds.height > 0
            ? contentView.bounds.height
            : TimelineConfiguration.default.videoLaneHeight
        let sizePoints = CGSize(width: tileWidth, height: tileHeight)

        let asset = clip.asset
        let start = sourceRange.startSeconds
        let duration = sourceRange.durationSeconds
        guard duration > 0 else { return }

        let generator = thumbnailGenerator
        let times: [(Int, Double)] = (0..<n).map { i in
            let u = (Double(i) + 0.5) / Double(n)
            let t = start + u * duration
            return (i, t)
        }

        // Serial awaits: `LocalThumbnailService` already serializes per URL; a plain loop avoids
        // N suspended tasks piling up while decodes run one at a time.
        thumbnailLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (idx, seconds) in times {
                guard !Task.isCancelled else { break }
                let image = await generator.videoFrame(
                    for: asset,
                    at: seconds,
                    size: sizePoints
                )
                guard !Task.isCancelled else { break }
                if idx < self.tileImageViews.count, let image {
                    self.tileImageViews[idx].image = image
                }
            }
        }
    }
}
