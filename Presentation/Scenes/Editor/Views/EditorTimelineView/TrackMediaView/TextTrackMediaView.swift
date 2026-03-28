//
//  TextTrackMediaView.swift
//  VideoEditor
//
//  Metin klibi için zaman çizelgesi karo önizlemesi; `ThumbnailGenerating` üzerinden
//  `OverlayGenerating` tabanlı düşük gecikmeli raster kullanır.

import UIKit

final class TextTrackMediaView: TrackMediaView {

    private let thumbnailGenerator: ThumbnailGenerating
    private var tileImageViews: [UIImageView] = []
    private var loadedImage: UIImage?

    init(frame: CGRect, clip: MediaClip, layout: TimelineLayoutProvider, thumbnailGenerator: ThumbnailGenerating) {
        self.thumbnailGenerator = thumbnailGenerator
        super.init(frame: frame, clip: clip, layout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupMediaContent() {
        contentView.backgroundColor = TimelineConfiguration.default.textTrackColor
        rebuildTiles()
        loadThumbnail()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTiles()
    }

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
            tile.image = loadedImage ?? tile.image
        }
    }

    private func syncTileViewCount(to count: Int) {
        while tileImageViews.count < count {
            let iv = makeTileImageView()
            iv.image = loadedImage ?? iv.image
            contentView.addSubview(iv)
            tileImageViews.append(iv)
        }
        while tileImageViews.count > count {
            tileImageViews.removeLast().removeFromSuperview()
        }
    }

    private func makeTileImageView() -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = TimelineConfiguration.default.imageTilePlaceholderColor
        iv.image = UIImage(systemName: "textformat")
        iv.tintColor = .white.withAlphaComponent(0.35)
        return iv
    }

    private func loadThumbnail() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let h = contentView.bounds.height > 0 ? contentView.bounds.height : 36
            let size = CGSize(width: tileWidth, height: h)

            let image = await thumbnailGenerator.thumbnail(for: clip.asset, size: size)
            guard !Task.isCancelled else { return }
            loadedImage = image
            let fallback = UIImage(systemName: "textformat")
            tileImageViews.forEach { $0.image = image ?? fallback }
        }
    }
}
