//
//  VideoTrackMediaView.swift
//  VideoEditor
//

import UIKit
import AVFoundation

final class VideoTrackMediaView: TrackMediaView {
    private let imageView = UIImageView()
    private static let cache = NSCache<NSString, UIImage>()

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
        guard case .video(let url) = clip.asset else { return }
        let key = url.absoluteString as NSString
        if let cached = Self.cache.object(forKey: key) {
            imageView.image = cached
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil)
            guard let cgImage else { return }
            let image = UIImage(cgImage: cgImage)
            Self.cache.setObject(image, forKey: key)
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }
}
