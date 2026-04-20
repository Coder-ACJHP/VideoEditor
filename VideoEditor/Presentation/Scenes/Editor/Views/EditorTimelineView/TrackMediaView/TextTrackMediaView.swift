//
// TextTrackMediaView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Timeline cell preview for a text clip; uses `ThumbnailGenerating` with a low-latency
//  `OverlayGenerating` raster path.

import UIKit

final class TextTrackMediaView: TrackMediaView {

    // Move title label forward when view is selected (mirrors AudioTrackMediaView behavior)
    private var leftPadding: CGFloat = 6 {
        didSet {
            guard oldValue != leftPadding else { return }
            layoutTitle(animated: true)
        }
    }

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = config.trackTitleFont
        label.textColor = config.trackTitleTextColor
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Improve legibility over busy backgrounds.
        label.layer.shadowColor = config.trackTitleShadow.color
        label.layer.shadowOffset = config.trackTitleShadow.offset
        label.layer.shadowRadius = config.trackTitleShadow.radius
        label.layer.shadowOpacity = config.trackTitleShadow.opacity
        label.layer.shouldRasterize = true
        label.layer.rasterizationScale = UIScreen.main.scale
        label.layer.masksToBounds = false
        return label
    }()

    override init(frame: CGRect, clip: MediaClip, layout: TimelineLayoutProvider) {
        super.init(frame: frame, clip: clip, layout: layout)
        // Hide base duration label; we will show duration next to text instead.
        durationLabelCanControlled = false
        showsDurationLabel = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupMediaContent() {
        contentView.backgroundColor = config.textTrackColor
        contentView.addSubview(titleLabel)
        updateTitle(using: clip.timelineRange)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutThumbnail()
        layoutTitle(animated: false)
    }

    private func layoutThumbnail() {
        let h = contentView.bounds.height
        guard h > 0 else { return }
        // Text clips start with a minimum visual width of 1 second on the timeline.
        let minWidth = layout.pointsPerSecond * 1.0
        let currentWidth = max(bounds.width, minWidth)
        frame.size.width = currentWidth
        contentView.frame = bounds
    }

    private func layoutTitle(animated: Bool) {
        let insetY: CGFloat = 0
        let newFrame = contentView.bounds.insetBy(dx: leftPadding, dy: insetY)

        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: .zero,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.15
            ) {
                self.titleLabel.frame = newFrame
            }
        } else {
            titleLabel.frame = newFrame
        }
    }

    private func updateTitle(using range: ClipTimeRange) {
        guard case let .text(descriptor) = clip.asset else {
            titleLabel.text = nil
            return
        }
        titleLabel.text = "\(descriptor.text) - \(durationString)"
    }

    override func applyTimelineRange(_ range: ClipTimeRange) {
        super.applyTimelineRange(range)
        // Keep duration text in sync with clip length.
        updateTitle(using: range)
    }

    override func setSelected(_ selected: Bool) {
        super.setSelected(selected)
        // Move title slightly inward so it stays visually on top of selection chrome.
        leftPadding = selected ? 24 : 6
    }
}
