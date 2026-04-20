//
// AudioTrackMediaView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Audio clip chrome: leading music icon + track title, remaining width shows a darker waveform.
//

import UIKit

// MARK: - Audio track clip view

final class AudioTrackMediaView: TrackMediaView {

    private let iconSize: CGFloat = 16.0
    // Move title and waveform forward when view is selected
    private var wfLeftPadding: CGFloat = 0 {
        didSet {
            guard oldValue != wfLeftPadding else { return }
            updateSubviewFrames(animated: true)
        }
    }
    private let wfTopBottomPadding: CGFloat = 5.0

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

    private let waveformImageView: UIImageView = {
        let imageView = UIImageView(image: nil)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    // Mocable waveform generator (protocol based)
    private let waveFormService: WaveformGenerating = LocalWaveformService()

    override init(frame: CGRect, clip: MediaClip, layout: TimelineLayoutProvider) {
        super.init(frame: frame, clip: clip, layout: layout)
        // Hide selectionView duration label
        durationLabelCanControlled = false
        showsDurationLabel = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupMediaContent() {
        contentView.backgroundColor = config.audioTrackColor
        contentView.addSubview(waveformImageView)
        contentView.addSubview(titleLabel)

        updateTitle(using: clip.timelineRange)
        Task { @MainActor in
            let image = await waveFormService.waveform(for: clip.asset, size: frame.size)
            waveformImageView.image = image
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSubviewFrames()
    }

    private func updateSubviewFrames(animated: Bool = false) {
        let newFrame = CGRect(
            x: wfLeftPadding,
            y: wfTopBottomPadding,
            width: bounds.width - (wfLeftPadding * 2),
            height: bounds.height - (wfTopBottomPadding * 2)
        )

        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: .zero,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.15
            ) {
                self.waveformImageView.frame = newFrame
                self.titleLabel.frame = newFrame
            }
        } else {
            waveformImageView.frame = newFrame
            titleLabel.frame = newFrame
        }
    }

    private func updateTitle(using range: ClipTimeRange) {
        let baseName = waveFormService.displayName(for: clip)
        titleLabel.text = "\(baseName) - \(durationString)"
    }

    override func applyTimelineRange(_ range: ClipTimeRange) {
        super.applyTimelineRange(range)
        // Keep duration text in sync with clip length.
        updateTitle(using: range)
    }

    override func setSelected(_ selected: Bool) {
        super.setSelected(selected)
        // move title label to forward (didSet will handle frame updates)
        wfLeftPadding = selected ? 24: 5
    }
}
