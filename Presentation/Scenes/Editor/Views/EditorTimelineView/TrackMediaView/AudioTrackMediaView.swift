//
//  AudioTrackMediaView.swift
//  VideoEditor
//
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
    private let config = TimelineConfiguration.default

    private let headerStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .center
        s.spacing = 4
        s.isUserInteractionEnabled = false
        return s
    }()

    private let noteIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor.white.withAlphaComponent(0.92)
        let sym = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        iv.image = UIImage(systemName: "music.note", withConfiguration: sym)?
            .withRenderingMode(.alwaysTemplate)
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        iv.accessibilityLabel = String(localized: "Audio track")
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.92)
        l.lineBreakMode = .byTruncatingTail
        l.numberOfLines = 1
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        l.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return l
    }()
    
    private let waveformStrip = AudioWaveformStripView()
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

        headerStack.addArrangedSubview(noteIconView)
        headerStack.addArrangedSubview(titleLabel)
        contentView.addSubview(waveformStrip)
        contentView.addSubview(headerStack)
        
        titleLabel.text = waveFormService.displayName(for: clip)
        waveformStrip.heightSeed = waveFormService.stableWaveformSeed(for: clip.id)
        waveformStrip.barColor = waveFormService.waveformColor(on: config.audioTrackColor)
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
        
        noteIconView.frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: iconSize,
                height: iconSize
            )
        )
        
        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: .zero,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.15
            ) {
                self.waveformStrip.frame = newFrame
                self.headerStack.frame = newFrame
            } completion: { [weak self] _ in
                self?.waveformStrip.setNeedsDisplay()
            }
        } else {
            waveformStrip.frame = newFrame
            headerStack.frame = newFrame
            waveformStrip.setNeedsDisplay()
        }
        
    }
    
    override func applyTimelineRange(_ range: ClipTimeRange) {
        super.applyTimelineRange(range)
        // Update duration title dynamically
        titleLabel.text = waveFormService.displayName(for: clip)
    }
    
    override func setSelected(_ selected: Bool) {
        super.setSelected(selected)
        // move title label to forward (didSet will handle frame updates)
        wfLeftPadding = selected ? 24: 5
    }
}
