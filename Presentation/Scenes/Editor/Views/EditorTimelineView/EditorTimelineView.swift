//
//  EditorTimelineView.swift
//  VideoEditor
//
//  The heart of the editor: a horizontally-scrollable timeline that shows
//  a time ruler, one audio track, and one (or more) video/image tracks.
//
//  Architecture
//  ┌──────────────────────────────────────────────────────────┐
//  │ EditorTimelineView                                       │
//  │  ┌────────────────────────────────────────────────────┐  │
//  │  │ scrollView (horizontal scroll only)                │  │
//  │  │  ┌──────────────────────────────────────────────┐  │  │
//  │  │  │ contentView  (width = duration × pxPerSec)   │  │  │
//  │  │  │  ┌──────────────────────────────────────┐    │  │  │
//  │  │  │  │ TimelineRulerView                    │    │  │  │
//  │  │  │  ├──────────────────────────────────────┤    │  │  │
//  │  │  │  │ MultipleTimelineTrackViews           │    │  │  │
//  │  │  │  ├──────────────────────────────────────┤    │  │  │
//  │  │  │  │ TimelineTrackView  (.video)  fixed   │    │  │  │
//  │  │  │  └──────────────────────────────────────┘    │  │  │
//  │  │  └──────────────────────────────────────────────┘  │  │
//  │  └────────────────────────────────────────────────────┘  │
//  │  ┌──┐  ← TimelinePlayheadView  (fixed, centered)         │
//  │  │  │    isUserInteractionEnabled = false                │
//  └──┴──┴──────────────────────────────────────────────────--┘
//
//  Centering trick:
//  scrollView.contentInset.left  = bounds.width / 2
//  scrollView.contentInset.right = bounds.width / 2
//  → time 0 starts exactly under the playhead when contentOffset.x = -left.
//

import UIKit
import CoreMedia

// MARK: - Delegate

protocol EditorTimelineViewDelegate: AnyObject {
    /// Fired while the user scrubs the timeline. `seconds` is clamped to ≥ 0.
    func timelineView(_ timeline: EditorTimelineView, didScrubToTime seconds: Double)
    /// Fired when the user taps a clip block. Use the media type to build a context sub menu.
    func timelineView(_ timeline: EditorTimelineView, didSelectClipWithMediaType mediaType: AssetIdentifier.MediaType)
    /// Fired when the user taps empty space in the timeline, deselecting all clips.
    func timelineViewDidDeselectAll(_ timeline: EditorTimelineView)
    /// Fired when a clip resize/move causes the total project duration to grow.
    func timelineView(_ timeline: EditorTimelineView, didExtendDurationTo seconds: Double)
}

// MARK: - EditorTimelineView

final class EditorTimelineView: UIView {

    private var config: TimelineConfiguration { .default }

    /// The total pixel height the timeline occupies.
    /// Expose as a static constant so EditorViewController can set a matching constraint.
    static let preferredHeight: CGFloat = {
        let c = TimelineConfiguration.default
        return c.rulerHeight
            + c.trackPadding
            + c.audioLaneHeight
            + c.trackSpacing
            + c.videoLaneHeight
            + c.trackPadding
    }()

    // MARK: - Public

    weak var delegate: EditorTimelineViewDelegate?
    private let thumbnailGenerator: ThumbnailGenerating

    // MARK: - Scroll Views

    private let rulerScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator   = false
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical   = false
        sv.isDirectionalLockEnabled = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let tracksScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator   = true
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical   = false
        sv.isDirectionalLockEnabled = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let rulerContentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let tracksContentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Timeline Sub-components

    private let rulerView = TimelineRulerView()
    private let tracksStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .fill
        sv.spacing = TimelineConfiguration.default.trackSpacing
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    private let playheadView = TimelinePlayheadView()

    // MARK: - State

    /// Backing constraints for timeline width; replaced when project duration changes.
    private var rulerContentWidthConstraint: NSLayoutConstraint?
    private var tracksContentWidthConstraint: NSLayoutConstraint?
    private var rulerHeightConstraint: NSLayoutConstraint?

    /// Runtime-created lanes (audio/video/overlay). Rebuilt on every configure call.
    private var dynamicTrackViews: [TimelineTrackView] = []

    /// Tap gesture that fires on empty space to clear all clip selections.
    private lazy var backgroundTapGesture: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.delegate = self
        return tap
    }()

    /// Prevents the scrub-delegate callback from firing when we move the offset programmatically.
    private var isSettingTimeExternally = false

    /// Set once after the first valid layout pass to avoid resetting contentOffset on rotation.
    private var hasAppliedInitialOffset = false

    // MARK: - Init

    init(frame: CGRect = .zero, thumbnailGenerator: ThumbnailGenerating) {
        self.thumbnailGenerator = thumbnailGenerator
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        applyInitialOffsetIfNeeded()
    }

    // MARK: - Private Setup

    private func setupView() {
        backgroundColor = .secondarySystemBackground
        translatesAutoresizingMaskIntoConstraints = false

        setupRulerScrollView()
        setupTracksScrollView()
        setupRulerContentView()
        setupTracksContentView()
        setupRuler()
        setupTracksStack()
        rebuildTrackViews(with: [])
        setupPlayhead()
    }

    private func setupRulerScrollView() {
        addSubview(rulerScrollView)
        let heightConstraint = rulerScrollView.heightAnchor.constraint(equalToConstant: config.rulerHeight)
        rulerHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            rulerScrollView.topAnchor.constraint(equalTo: topAnchor),
            rulerScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rulerScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightConstraint,
        ])
    }

    private func setupTracksScrollView() {
        tracksScrollView.delegate = self
        tracksScrollView.addGestureRecognizer(backgroundTapGesture)
        addSubview(tracksScrollView)

        NSLayoutConstraint.activate([
            tracksScrollView.topAnchor.constraint(equalTo: rulerScrollView.bottomAnchor),
            tracksScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tracksScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tracksScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupRulerContentView() {
        rulerScrollView.addSubview(rulerContentView)

        let initialWidth = CGFloat(config.minimumProjectDuration) * config.pixelsPerSecond + (config.horizontalEdgePadding * 2)
        let widthConstraint = rulerContentView.widthAnchor.constraint(equalToConstant: initialWidth)
        rulerContentWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            rulerContentView.topAnchor.constraint(equalTo: rulerScrollView.contentLayoutGuide.topAnchor),
            rulerContentView.leadingAnchor.constraint(equalTo: rulerScrollView.contentLayoutGuide.leadingAnchor),
            rulerContentView.trailingAnchor.constraint(equalTo: rulerScrollView.contentLayoutGuide.trailingAnchor),
            rulerContentView.bottomAnchor.constraint(equalTo: rulerScrollView.contentLayoutGuide.bottomAnchor),
            rulerContentView.heightAnchor.constraint(equalTo: rulerScrollView.frameLayoutGuide.heightAnchor),
            widthConstraint,
        ])
    }

    private func setupTracksContentView() {
        tracksScrollView.addSubview(tracksContentView)

        let initialWidth = CGFloat(config.minimumProjectDuration) * config.pixelsPerSecond
        let widthConstraint = tracksContentView.widthAnchor.constraint(equalToConstant: initialWidth)
        tracksContentWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            tracksContentView.topAnchor.constraint(equalTo: tracksScrollView.contentLayoutGuide.topAnchor),
            tracksContentView.leadingAnchor.constraint(equalTo: tracksScrollView.contentLayoutGuide.leadingAnchor),
            tracksContentView.trailingAnchor.constraint(equalTo: tracksScrollView.contentLayoutGuide.trailingAnchor),
            tracksContentView.bottomAnchor.constraint(equalTo: tracksScrollView.contentLayoutGuide.bottomAnchor),
            tracksContentView.heightAnchor.constraint(greaterThanOrEqualTo: tracksScrollView.frameLayoutGuide.heightAnchor),
            widthConstraint,
        ])
    }

    private func setupRuler() {
        rulerView.pixelsPerSecond = config.pixelsPerSecond
        rulerContentView.addSubview(rulerView)
        NSLayoutConstraint.activate([
            rulerView.topAnchor.constraint(equalTo: rulerContentView.topAnchor),
            rulerView.leadingAnchor.constraint(equalTo: rulerContentView.leadingAnchor, constant: config.horizontalEdgePadding),
            rulerView.trailingAnchor.constraint(equalTo: rulerContentView.trailingAnchor, constant: -config.horizontalEdgePadding),
            rulerView.bottomAnchor.constraint(equalTo: rulerContentView.bottomAnchor),
        ])
    }

    private func setupTracksStack() {
        tracksContentView.addSubview(tracksStackView)
        NSLayoutConstraint.activate([
            tracksStackView.leadingAnchor.constraint(equalTo: tracksContentView.leadingAnchor),
            tracksStackView.trailingAnchor.constraint(equalTo: tracksContentView.trailingAnchor),
            tracksStackView.topAnchor.constraint(greaterThanOrEqualTo: tracksContentView.topAnchor, constant: config.trackPadding),
            tracksStackView.bottomAnchor.constraint(lessThanOrEqualTo: tracksContentView.bottomAnchor, constant: -config.trackPadding),
            tracksStackView.centerYAnchor.constraint(equalTo: tracksContentView.centerYAnchor),
        ])
    }

    private func setupPlayhead() {
        // The playhead is a non-interactive overlay on top of everything, pinned to the
        // EditorTimelineView (not the scroll view) so it never moves with the content.
        addSubview(playheadView)
        NSLayoutConstraint.activate([
            playheadView.topAnchor.constraint(equalTo: topAnchor),
            playheadView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playheadView.centerXAnchor.constraint(equalTo: centerXAnchor),
            playheadView.widthAnchor.constraint(equalToConstant: 12),
        ])
    }

    // MARK: - Initial Offset

    /// Centers the timeline at t = 0 after the first valid layout.
    /// Called from layoutSubviews to guarantee bounds are non-zero.
    private func applyInitialOffsetIfNeeded() {
        let half = bounds.width / 2
        guard half > 0 else { return }

        // Content insets create virtual padding so time=0 can sit under the centered playhead.
        rulerScrollView.contentInset = UIEdgeInsets(top: 0, left: half, bottom: 0, right: half)
        tracksScrollView.contentInset = UIEdgeInsets(top: 0, left: half, bottom: 0, right: half)

        if !hasAppliedInitialOffset {
            hasAppliedInitialOffset = true
            // Offset -left puts the very start of the content under the playhead.
            tracksScrollView.contentOffset = CGPoint(x: -half, y: 0)
            rulerScrollView.contentOffset = CGPoint(x: config.horizontalEdgePadding - half, y: 0)
        }
    }

    // MARK: - Public API

    /// Populates the timeline from the project model.
    /// Safe to call multiple times (e.g. after adding / removing clips).
    func configure(with project: EditingProject) {
        let duration = max(project.totalDuration.seconds, config.minimumProjectDuration)
        let tracksTimelineWidth = CGFloat(duration) * config.pixelsPerSecond
        let rulerTimelineWidth = tracksTimelineWidth + (config.horizontalEdgePadding * 2)
        rulerContentWidthConstraint?.constant = rulerTimelineWidth
        tracksContentWidthConstraint?.constant = tracksTimelineWidth

        rebuildTrackViews(with: project.tracks)

        rulerView.setNeedsDisplay()
        updateVerticalScrollingState()
        layoutIfNeeded()
    }

    /// Programmatically scrolls the timeline so the playhead sits over `seconds`.
    /// Does NOT fire the delegate.
    func setCurrentTime(_ seconds: Double) {
        let half = tracksScrollView.contentInset.left
        guard half > 0 else { return }
        let x = CGFloat(seconds) * config.pixelsPerSecond - half
        isSettingTimeExternally = true
        let y = tracksScrollView.contentOffset.y
        let offset = CGPoint(x: x, y: y)
        tracksScrollView.setContentOffset(offset, animated: false)
        rulerScrollView.setContentOffset(CGPoint(x: x + config.horizontalEdgePadding, y: 0), animated: false)
        isSettingTimeExternally = false
    }

    /// Expanded preview mode:
    /// - hides ruler and gives that vertical area to track lanes
    /// - focuses the bottom video lane as close to center as possible
    func setExpandedPreviewMode(_ isExpanded: Bool, animated: Bool) {
        rulerHeightConstraint?.constant = isExpanded ? 0 : config.rulerHeight
        rulerScrollView.alpha = isExpanded ? 0 : 1
        rulerScrollView.isUserInteractionEnabled = !isExpanded

        let updates = {
            self.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseInOut, animations: updates)
        } else {
            updates()
        }

        if isExpanded {
            focusVideoLaneNearCenter(animated: animated)
        } else {
            // Restore default vertical position for normal mode.
            tracksScrollView.setContentOffset(
                CGPoint(x: tracksScrollView.contentOffset.x, y: 0),
                animated: animated
            )
        }
    }

    // MARK: - Deselection

    /// Deselects all clips across every track lane and notifies the delegate.
    func deselectAllTracks() {
        dynamicTrackViews.forEach { $0.deselectAll() }
        delegate?.timelineViewDidDeselectAll(self)
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        deselectAllTracks()
    }

    // MARK: - Dynamic Tracks

    private func rebuildTrackViews(with tracks: [MediaTrack]) {
        tracksStackView.arrangedSubviews.forEach { view in
            tracksStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        dynamicTrackViews.removeAll()

        let overlays = tracks.filter { $0.trackType == .overlay }
        let audios = tracks.filter { $0.trackType == .audio }
        let videos = tracks.filter { $0.trackType == .video }

        let orderedTracks = overlays + (audios.isEmpty ? [nil] : audios.map { Optional($0) }) + (videos.isEmpty ? [nil] : videos.map { Optional($0) })

        for maybeTrack in orderedTracks {

            let model: MediaTrack?
            let trackType: MediaTrack.TrackType

            if let track = maybeTrack {
                model = track
                trackType = track.trackType
            } else {
                // Placeholder lanes keep base timeline structure always visible.
                model = nil
                trackType = dynamicTrackViews.contains(where: { $0.trackType == .audio }) ? .video : .audio
            }

            let lane = TimelineTrackView(trackType: trackType, thumbnailGenerator: thumbnailGenerator)
            lane.delegate = self
            lane.heightAnchor.constraint(equalToConstant: config.laneHeight(for: trackType)).isActive = true
            lane.configure(with: model, pixelsPerSecond: config.pixelsPerSecond)
            tracksStackView.addArrangedSubview(lane)
            dynamicTrackViews.append(lane)
        }
    }

    // NOTE: Base audio/video placeholders are injected directly in `rebuildTrackViews`
    // to preserve strict visual order: overlays -> audio -> video.

    private func updateVerticalScrollingState() {
        layoutIfNeeded()
        let contentHeight = tracksStackView.systemLayoutSizeFitting(
            CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height + (config.trackPadding * 2)
        let visibleHeight = tracksScrollView.bounds.height
        let needsVerticalScroll = contentHeight > visibleHeight
        tracksScrollView.alwaysBounceVertical = needsVerticalScroll
        tracksScrollView.showsVerticalScrollIndicator = needsVerticalScroll
    }

    private func focusVideoLaneNearCenter(animated: Bool) {
        guard let videoLane = dynamicTrackViews.last(where: { $0.trackType == .video }) else { return }
        layoutIfNeeded()

        let frameInContent = tracksContentView.convert(videoLane.frame, from: tracksStackView)
        let visibleHeight = tracksScrollView.bounds.height
        guard visibleHeight > 0 else { return }

        let preferredY = frameInContent.midY - (visibleHeight / 2)
        let maxY = max(0, tracksScrollView.contentSize.height - visibleHeight)
        let clampedY = min(max(preferredY, 0), maxY)

        tracksScrollView.setContentOffset(
            CGPoint(x: tracksScrollView.contentOffset.x, y: clampedY),
            animated: animated
        )
    }
}

// MARK: - UIScrollViewDelegate

extension EditorTimelineView: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isSettingTimeExternally else { return }
        guard scrollView === tracksScrollView else { return }

        isSettingTimeExternally = true
        rulerScrollView.contentOffset.x = tracksScrollView.contentOffset.x + config.horizontalEdgePadding
        isSettingTimeExternally = false

        // contentOffset.x == -contentInset.left  →  time 0 is under the playhead.
        let rawOffset = tracksScrollView.contentOffset.x + tracksScrollView.contentInset.left
        let time = max(Double(rawOffset / config.pixelsPerSecond), 0)
        delegate?.timelineView(self, didScrubToTime: time)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension EditorTimelineView: UIGestureRecognizerDelegate {

    /// Only recognise the background-tap when the touch lands on empty space,
    /// not on a clip (TrackMediaView or any of its subviews).
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard gestureRecognizer === backgroundTapGesture else { return true }
        var current = touch.view
        while let view = current {
            if view is TrackMediaView { return false }
            current = view.superview
        }
        return true
    }
}

// MARK: - TimelineTrackViewDelegate

extension EditorTimelineView: TimelineTrackViewDelegate {

    func trackView(_ view: TimelineTrackView, didTapClipAt index: Int, mediaType: AssetIdentifier.MediaType) {
        for lane in dynamicTrackViews where lane !== view {
            lane.deselectAll()
        }
        delegate?.timelineView(self, didSelectClipWithMediaType: mediaType)
    }

    func trackView(_ view: TimelineTrackView, didRequestTimelineExtensionTo newDuration: Double) {
        let tracksWidth = CGFloat(newDuration) * config.pixelsPerSecond
        let rulerWidth  = tracksWidth + (config.horizontalEdgePadding * 2)

        tracksContentWidthConstraint?.constant = tracksWidth
        rulerContentWidthConstraint?.constant  = rulerWidth

        rulerView.setNeedsDisplay()
        layoutIfNeeded()

        delegate?.timelineView(self, didExtendDurationTo: newDuration)
    }
}
