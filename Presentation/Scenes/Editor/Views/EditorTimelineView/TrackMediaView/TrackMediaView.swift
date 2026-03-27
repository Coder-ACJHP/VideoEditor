//
//  TrackMediaView.swift
//  VideoEditor
//

import UIKit

protocol TrackMediaViewDelegate: AnyObject {
    func trackMediaViewDidToggleSelection(_ view: TrackMediaView)
    func trackMediaView(_ view: TrackMediaView, didChangeTimelineRange range: ClipTimeRange, sourceRange: ClipTimeRange, allowExtension: Bool)
}

class TrackMediaView: UIView {

    private var config: TimelineConfiguration { .default }

    weak var delegate: TrackMediaViewDelegate?

    let clip: MediaClip
    let pixelsPerSecond: CGFloat
    private(set) var isSelected = false
    /// When true, center drag is disabled and contiguity is enforced.
    var isMasterTrack = false
    var contentView: UIView { mediaContainerView }

    private var timelineRange: ClipTimeRange
    private(set) var sourceRange: ClipTimeRange
    /// The total source asset duration — upper bound for video/audio trim.
    private let maxSourceEnd: Double
    private var maxTrackDuration: Double = 0

    private lazy var panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleMovePan(_:)))
    private lazy var leftHandlePan = UIPanGestureRecognizer(target: self, action: #selector(handleLeftTrimPan(_:)))
    private lazy var rightHandlePan = UIPanGestureRecognizer(target: self, action: #selector(handleRightTrimPan(_:)))

    private var initialFrame: CGRect = .zero
    private var initialRange: ClipTimeRange = .zero
    private var initialSourceRange: ClipTimeRange = .zero

    private let mediaContainerView = UIView()
    private let selectionBorderView = UIView()
    private let durationLabel = UILabel()
    private let leftHandle = UILabel()
    private let rightHandle = UILabel()

    init(frame: CGRect, clip: MediaClip, pixelsPerSecond: CGFloat) {
        self.clip = clip
        self.pixelsPerSecond = max(pixelsPerSecond, 1)
        self.timelineRange = clip.timelineRange
        self.sourceRange = clip.sourceRange
        self.maxSourceEnd = clip.sourceRange.endSeconds
        super.init(frame: frame)
        setupView()
        updateDurationLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectionBorderView.frame = bounds
        durationLabel.frame = CGRect(x: config.selectionHandleWidth, y: 2, width: min(bounds.width - 16, 40), height: 16)
        leftHandle.frame = CGRect(x: 0, y: 0, width: config.selectionHandleWidth, height: bounds.height)
        rightHandle.frame = CGRect(x: bounds.width - config.selectionHandleWidth, y: 0, width: config.selectionHandleWidth, height: bounds.height)
        mediaContainerView.frame = bounds
        mediaContainerView.layer.cornerRadius = config.clipCornerRadius - 2
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        selectionBorderView.isHidden = !selected
        durationLabel.isHidden = !selected
        leftHandle.isHidden = !selected
        rightHandle.isHidden = !selected

        leftHandlePan.isEnabled = selected
        rightHandlePan.isEnabled = selected
        panGesture.isEnabled = selected && !isMasterTrack
    }

    func applyTimelineRange(_ range: ClipTimeRange) {
        timelineRange = range
        updateDurationLabel()
    }

    func applySourceRange(_ range: ClipTimeRange) {
        sourceRange = range
    }

    func updateTrackLimits(maxDuration: Double) {
        maxTrackDuration = max(maxDuration, config.minClipDuration)
    }

    func setupMediaContent() {}

    /// Called after a trim gesture ends so subclasses can update
    /// visual content (e.g. reload thumbnails with the new source offset).
    func didFinishTrimming() {}

    private func setupView() {
        clipsToBounds = false
        isUserInteractionEnabled = true
        layer.cornerRadius = config.clipCornerRadius
        backgroundColor = .clear

        mediaContainerView.clipsToBounds = true
        addSubview(mediaContainerView)
        setupMediaContent()

        selectionBorderView.layer.borderColor = config.selectionColor.cgColor
        selectionBorderView.layer.borderWidth = config.selectionBorderWidth
        selectionBorderView.layer.cornerRadius = config.clipCornerRadius
        selectionBorderView.backgroundColor = .clear
        addSubview(selectionBorderView)

        durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        durationLabel.textColor = .white
        durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        durationLabel.layer.cornerRadius = 4
        durationLabel.clipsToBounds = true
        durationLabel.textAlignment = .center
        addSubview(durationLabel)

        configureHandle(leftHandle, isLeft: true)
        configureHandle(rightHandle, isLeft: false)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        addGestureRecognizer(panGesture)
        leftHandle.addGestureRecognizer(leftHandlePan)
        rightHandle.addGestureRecognizer(rightHandlePan)

        setSelected(false)
    }

    private func configureHandle(_ label: UILabel, isLeft: Bool) {
        label.text = isLeft ? "❮" : "❯"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .black
        label.backgroundColor = config.selectionColor
        label.layer.cornerRadius = config.clipCornerRadius - 2
        label.layer.maskedCorners = isLeft ? [.layerMinXMinYCorner, .layerMinXMaxYCorner] : [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        label.layer.masksToBounds = true
        label.isUserInteractionEnabled = true
        addSubview(label)
    }

    private func updateDurationLabel() {
        let total = max(Int(timelineRange.durationSeconds.rounded()), 0)
        durationLabel.text = String(format: "%02d:%02d", total / 60, total % 60)
    }

    @objc private func handleTap() {
        delegate?.trackMediaViewDidToggleSelection(self)
    }

    @objc private func handleMovePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            guard timelineRange.durationSeconds < maxTrackDuration else {
                gesture.state = .cancelled
                return
            }
            initialFrame = frame
            initialRange = timelineRange
        case .changed:
            let tx = gesture.translation(in: superview).x
            let trackWidthPx = CGFloat(maxTrackDuration) * pixelsPerSecond
            let maxOriginX = max(trackWidthPx - frame.width, 0)
            let x = min(max(initialFrame.origin.x + tx, 0), maxOriginX)
            frame.origin.x = x
            timelineRange.startSeconds = Double(x / pixelsPerSecond)
            notifyRangeChanged(allowExtension: false)
        default:
            break
        }
    }

    @objc private func handleLeftTrimPan(_ gesture: UIPanGestureRecognizer) {
        let isTimeBasedMedia: Bool = {
            switch clip.asset.mediaType {
            case .video, .audio:
                return true
            case .image:
                return false
            }
        }()
        switch gesture.state {
        case .began:
            initialFrame = frame
            initialRange = timelineRange
            initialSourceRange = sourceRange
        case .changed:
            let tx = gesture.translation(in: superview).x
            let minWidth = CGFloat(config.minClipDuration) * pixelsPerSecond

            if isMasterTrack {
                // Master track: only width changes; origin.x is set by
                // enforceContiguity in the delegate, keeping clips gap/overlap-free.
                let deltaSeconds = Double(tx / pixelsPerSecond)
                let newDuration: Double

                if isTimeBasedMedia {
                    let sourceEnd = initialSourceRange.endSeconds
                    let rawSourceStart = initialSourceRange.startSeconds + deltaSeconds
                    let clampedSourceStart = min(max(rawSourceStart, 0), sourceEnd - config.minClipDuration)
                    sourceRange.startSeconds = clampedSourceStart
                    newDuration = sourceEnd - clampedSourceStart
                    sourceRange.durationSeconds = newDuration
                } else {
                    newDuration = max(initialRange.durationSeconds - deltaSeconds, config.minClipDuration)
                    sourceRange.durationSeconds = newDuration
                }

                frame.size.width = CGFloat(newDuration) * pixelsPerSecond
                timelineRange.durationSeconds = newDuration
                notifyRangeChanged(allowExtension: true)
            } else {
                // Non-master: move the left edge freely within track bounds.
                let minClampedX: CGFloat
                if isTimeBasedMedia {
                    minClampedX = max(0, initialFrame.minX - CGFloat(initialSourceRange.startSeconds) * pixelsPerSecond)
                } else {
                    minClampedX = 0
                }

                let maxX = initialFrame.maxX - minWidth
                let clampedX = min(max(initialFrame.minX + tx, minClampedX), maxX)
                let newWidth = initialFrame.maxX - clampedX
                frame.origin.x = clampedX
                frame.size.width = newWidth

                let startDeltaSeconds = Double((clampedX - initialFrame.minX) / pixelsPerSecond)
                timelineRange.startSeconds = initialRange.startSeconds + startDeltaSeconds
                timelineRange.durationSeconds = max(Double(newWidth / pixelsPerSecond), config.minClipDuration)

                if isTimeBasedMedia {
                    sourceRange.startSeconds = max(initialSourceRange.startSeconds + startDeltaSeconds, 0)
                    sourceRange.durationSeconds = timelineRange.durationSeconds
                }

                notifyRangeChanged(allowExtension: true)
            }
        case .ended, .cancelled:
            didFinishTrimming()
        default:
            break
        }
    }

    @objc private func handleRightTrimPan(_ gesture: UIPanGestureRecognizer) {
        let isTimeBasedMedia: Bool = {
            switch clip.asset.mediaType {
            case .video, .audio:
                return true
            case .image:
                return false
            }
        }()
        switch gesture.state {
        case .began:
            initialFrame = frame
            initialRange = timelineRange
            initialSourceRange = sourceRange
        case .changed:
            let tx = gesture.translation(in: superview).x
            let minWidth = CGFloat(config.minClipDuration) * pixelsPerSecond
            let candidateWidth = initialFrame.width + tx

            let maxWidth: CGFloat
            if isTimeBasedMedia {
                let maxDuration = maxSourceEnd - sourceRange.startSeconds
                maxWidth = CGFloat(maxDuration) * pixelsPerSecond
            } else {
                maxWidth = .greatestFiniteMagnitude
            }

            var allowedMaxWidth = maxWidth
            if !isMasterTrack {
                let maxEndX = CGFloat(maxTrackDuration) * pixelsPerSecond
                let availableWidth = max(maxEndX - initialFrame.minX, minWidth)
                allowedMaxWidth = min(allowedMaxWidth, availableWidth)
            }

            let newWidth = min(max(candidateWidth, minWidth), allowedMaxWidth)
            frame.size.width = newWidth
            timelineRange.durationSeconds = max(Double(newWidth / pixelsPerSecond), config.minClipDuration)

            if isTimeBasedMedia {
                sourceRange.durationSeconds = timelineRange.durationSeconds
            }

            notifyRangeChanged(allowExtension: true)
        case .ended, .cancelled:
            didFinishTrimming()
        default:
            break
        }
    }

    private func notifyRangeChanged(allowExtension: Bool) {
        updateDurationLabel()
        setNeedsLayout()
        delegate?.trackMediaView(self, didChangeTimelineRange: timelineRange, sourceRange: sourceRange, allowExtension: allowExtension)
    }
}
