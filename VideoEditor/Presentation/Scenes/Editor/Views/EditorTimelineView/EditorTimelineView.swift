//
// EditorTimelineView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

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
    func timelineView(
        _ timeline: EditorTimelineView,
        didSelectClipWithId clipId: UUID,
        mediaType: AssetIdentifier.MediaType,
        laneTrackType: MediaTrack.TrackType
    )
    /// Fired when the user taps empty space in the timeline, deselecting all clips.
    func timelineViewDidDeselectAll(_ timeline: EditorTimelineView)
    /// Fired when a clip resize/move causes the total project duration to grow.
    func timelineView(_ timeline: EditorTimelineView, didExtendDurationTo seconds: Double)
    /// Fired when any lane updates its underlying track model (drag/trim/collision).
    func timelineView(_ timeline: EditorTimelineView, didUpdateTracks tracks: [MediaTrack])
    /// User tapped the floating add-media control (photo library).
    func timelineViewDidTapAddMedia(_ timeline: EditorTimelineView)
    /// User opened the transition picker on a master-track seam (after clip at index).
    func timelineView(
        _ timeline: EditorTimelineView,
        didRequestTransitionPickerAfterClipAt clipIndex: Int,
        currentTransition: ClipTransition?
    )
}

// MARK: - EditorTimelineView

@MainActor
final class EditorTimelineView: UIView {
    
    private var config: TimelineConfiguration { .default }
    private var timelineLayout: TimelineLayoutProvider { config.timelineLayout }
    
    // MARK: - Public
    
    weak var delegate: EditorTimelineViewDelegate?
    private let thumbnailGenerator: ThumbnailGenerating
    
    /// When the user scrolls the timeline horizontally, ignore playback-driven auto-scroll to avoid fighting the finger.
    var isUserAdjustingHorizontalScroll: Bool {
        tracksScrollView.isDragging || tracksScrollView.isDecelerating
    }
    
    // MARK: - Scroll Views
    
    // Disable scrolling to avoid miss actual time in timeline
    private let rulerScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator   = false
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical   = false
        sv.isDirectionalLockEnabled = true
        sv.isScrollEnabled = false
        // Playhead ↔ `contentOffset` depends on `contentInset`; safe-area changes can misalign early seconds until layout settles.
        sv.contentInsetAdjustmentBehavior = .never
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
        sv.contentInsetAdjustmentBehavior = .never
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let rulerContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
    
    /// Floating control over the track stack; opens the system photo picker from the delegate.
    private lazy var addMediaButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "plus")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        config.cornerStyle = .medium
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.addDefaultAnimation()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = String(localized: "Add media")
        button.accessibilityIdentifier = "timeline.addMedia"
        button.addTarget(self, action: #selector(addMediaTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var reorderClipsWarningLabel: UILabel = {
        let label = UILabel()
        label.text = "Reordering removes the transition between two clips."
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .caption2)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = config.warningLabelTextColor
        label.isHidden = true
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - State
    
    /// Backing constraints for timeline width; replaced when project duration changes.
    private var rulerContentWidthConstraint: NSLayoutConstraint?
    private var tracksContentWidthConstraint: NSLayoutConstraint?
    private var rulerHeightConstraint: NSLayoutConstraint?
    
    /// Runtime-created lanes (audio/video/overlay). Rebuilt on every configure call.
    private var dynamicTrackViews: [TimelineTrackView] = []
    /// Mutable snapshot of tracks currently rendered in the timeline.
    private var currentTracks: [MediaTrack] = []
    
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
    
    /// If `setCurrentTime` runs before layout (inset still zero), stash here and apply at end of `layoutSubviews`.
    private var pendingPlaybackSyncSeconds: Double?
    
    private let skeletonAnimator = TimelineSkeletonAnimator()

    /// Applies or clears `transitionOut` on the master video clip at `clipIndex` and syncs the timeline model.
    func applyMasterTrackTransitionOut(_ transition: ClipTransition?, afterClipAt clipIndex: Int) {
        guard let lane = dynamicTrackViews.first(where: { $0.trackType == .video }) else { return }
        lane.commitMasterTransitionOut(transition, afterClipAt: clipIndex)
    }

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
        bringSubviewToFront(playheadView)
        bringSubviewToFront(addMediaButton)
        bringSubviewToFront(reorderClipsWarningLabel)
    }
    
    // MARK: - Private Setup
    
    private func setupView() {
        backgroundColor = config.backgroundColor
        translatesAutoresizingMaskIntoConstraints = false
        
        setupRulerScrollView()
        setupTracksScrollView()
        setupRulerContentView()
        setupTracksContentView()
        setupRuler()
        setupTracksStack()
        rebuildTrackViews(with: [])
        setupPlayhead()
        setupAddMediaButton()
        setupWarningLabel()
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
        
        let initialWidth = timelineLayout.xPosition(forSeconds: config.minimumProjectDuration) + (config.horizontalEdgePadding * 2)
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
        
        let initialWidth = timelineLayout.xPosition(forSeconds: config.minimumProjectDuration)
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
        rulerView.layout = config.timelineLayout
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
    
    private func setupAddMediaButton() {
        addSubview(addMediaButton)
        let size: CGFloat = 42
        NSLayoutConstraint.activate([
            addMediaButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            addMediaButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            addMediaButton.widthAnchor.constraint(equalToConstant: size),
            addMediaButton.heightAnchor.constraint(equalToConstant: size),
        ])
        
        addMediaButton
            .dropOuterShadow(
                withColor: .white.withAlphaComponent(0.2),
                radius: 10,
                offset: .zero
            )
    }
    
    private func setupWarningLabel() {
        addSubview(reorderClipsWarningLabel)
        NSLayoutConstraint.activate([
            reorderClipsWarningLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            reorderClipsWarningLabel.centerYAnchor.constraint(equalTo: addMediaButton.centerYAnchor)
        ])
    }
    
    @objc private func addMediaTapped() {
        delegate?.timelineViewDidTapAddMedia(self)
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
        
        if let pending = pendingPlaybackSyncSeconds {
            pendingPlaybackSyncSeconds = nil
            setCurrentTime(pending)
        }
    }
    
    // MARK: - Public API
    
    /// Populates the timeline from the project model.
    /// Safe to call multiple times (e.g. after adding / removing clips).
    func configure(with project: EditingProject) {
        
        skeletonAnimator.start(stackView: tracksStackView, overlayHost: tracksContentView)
        
        currentTracks = project.tracks
        let duration = max(project.totalDuration.seconds, config.minimumProjectDuration)
        let tracksTimelineWidth = timelineLayout.xPosition(forSeconds: duration)
        let rulerTimelineWidth = tracksTimelineWidth + (config.horizontalEdgePadding * 2)
        rulerContentWidthConstraint?.constant = rulerTimelineWidth
        tracksContentWidthConstraint?.constant = tracksTimelineWidth
        
        rebuildTrackViews(with: currentTracks) { [weak self] in
            guard let self else { return }
            
            rulerView.setNeedsDisplay()
            updateVerticalScrollingState()
            layoutIfNeeded()
            // Stop the animation
            skeletonAnimator.stop()
        }
    }
    
    /// Programmatic selection from canvas or elsewhere: highlights the clip on its lane and clears other lanes.
    func selectClipOnTimeline(withId clipId: UUID) {
        var selectedLane: TimelineTrackView?
        for lane in dynamicTrackViews {
            if lane.selectClip(withClipId: clipId) {
                selectedLane = lane
                break
            }
        }
        guard selectedLane != nil else { return }
        for lane in dynamicTrackViews where lane !== selectedLane {
            lane.deselectAll()
        }
        guard let (laneTrackType, mediaType) = laneAndMediaTypeForClipId(clipId) else { return }
        delegate?.timelineView(self, didSelectClipWithId: clipId, mediaType: mediaType, laneTrackType: laneTrackType)
    }

    private func laneAndMediaTypeForClipId(_ clipId: UUID) -> (MediaTrack.TrackType, AssetIdentifier.MediaType)? {
        for track in currentTracks {
            if let clip = track.clips.first(where: { $0.id == clipId }) {
                return (track.trackType, clip.asset.mediaType)
            }
        }
        return nil
    }
    
    /// Programmatically scrolls the timeline so the playhead sits over `seconds`.
    /// Does NOT fire the delegate.
    func setCurrentTime(_ seconds: Double) {
        let half = tracksScrollView.contentInset.left
        guard half > 0 else {
            pendingPlaybackSyncSeconds = seconds
            return
        }
        pendingPlaybackSyncSeconds = nil
        let timeX = timelineLayout.xPosition(forSeconds: seconds)
        let x = timeX - half
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
        
        let updates = { self.layoutIfNeeded() }
        
        if animated {
            UIView
                .animate(
                    withDuration: 0.22,
                    delay: 0,
                    options: .curveEaseInOut,
                    animations: updates
                )
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
    
    private func rebuildTrackViews(with tracks: [MediaTrack], completion: (() -> Void)? = nil)  {
        let overlays = tracks.filter { $0.trackType == .overlay }
        let audios = tracks.filter { $0.trackType == .audio }
        let videos = tracks.filter { $0.trackType == .video }
        
        let masterTrackDuration = videos
            .flatMap(\.clips)
            .map(\.timelineRange.endSeconds)
            .max()
        
        // 1. Define the target structural layout for the timeline lanes.
        // We explicitly map the desired order (Overlays -> Audios -> Videos).
        // This safely replaces the previous logic of checking an actively-clearing array.
        var targetTracks: [(model: MediaTrack?, type: MediaTrack.TrackType)] = []
        
        targetTracks.append(contentsOf: overlays.map { ($0, .overlay) })
        targetTracks.append(contentsOf: audios.isEmpty ? [(nil, .audio)] : audios.map { ($0, .audio) })
        targetTracks.append(contentsOf: videos.isEmpty ? [(nil, .video)] : videos.map { ($0, .video) })
        
        var updatedTrackViews: [TimelineTrackView] = []
        
        // 2. Synchronize existing UI with the target tracks: Reuse, Replace, or Add.
        for (index, target) in targetTracks.enumerated() {
            let durationLimit: Double? = (target.type == .video) ? nil : masterTrackDuration
            
            // Check if we can reuse an existing view at this index
            if index < dynamicTrackViews.count, dynamicTrackViews[index].trackType == target.type {
                // REUSE: The existing view matches the required track type. Just update its data.
                let lane = dynamicTrackViews[index]
                lane.configure(
                    with: target.model,
                    layout: config.timelineLayout,
                    durationLimitOverride: durationLimit
                )
                updatedTrackViews.append(lane)
                
            } else {
                // REPLACE or INSERT: The view is either missing or is the wrong track type.
                let lane = TimelineTrackView(trackType: target.type, thumbnailGenerator: thumbnailGenerator)
                lane.delegate = self
                lane.heightAnchor.constraint(equalToConstant: config.laneHeight(for: target.type)).isActive = true
                lane.configure(
                    with: target.model,
                    layout: config.timelineLayout,
                    durationLimitOverride: durationLimit
                )
                
                if index < dynamicTrackViews.count {
                    // Replace the old mismatched view inline
                    let oldView = dynamicTrackViews[index]
                    tracksStackView.removeArrangedSubview(oldView)
                    oldView.removeFromSuperview()
                    tracksStackView.insertArrangedSubview(lane, at: index)
                } else {
                    // Append the new view to the bottom of the stack
                    tracksStackView.addArrangedSubview(lane)
                }
                updatedTrackViews.append(lane)
            }
        }
        
        // 3. CLEANUP: Remove any leftover views if the project track count shrank.
        if dynamicTrackViews.count > targetTracks.count {
            let leftovers = dynamicTrackViews.suffix(from: targetTracks.count)
            leftovers.forEach { oldView in
                tracksStackView.removeArrangedSubview(oldView)
                oldView.removeFromSuperview()
            }
        }
        
        // 4. Commit the new state
        dynamicTrackViews = updatedTrackViews
        
        // 5. Complete operations (wait a sec to complete laying out views)
        let task = DispatchWorkItem { completion?() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
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
        let time = max(timelineLayout.seconds(forXPosition: rawOffset), 0)
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

    func trackView(
        _ view: TimelineTrackView,
        didTapClipAt index: Int,
        clipId: UUID,
        mediaType: AssetIdentifier.MediaType,
        laneTrackType: MediaTrack.TrackType
    ) {
        for lane in dynamicTrackViews where lane !== view {
            lane.deselectAll()
        }
        delegate?.timelineView(self, didSelectClipWithId: clipId, mediaType: mediaType, laneTrackType: laneTrackType)
    }

    func trackViewDidDeselectClip(_ view: TimelineTrackView) {
        delegate?.timelineViewDidDeselectAll(self)
    }

    func trackView(_ view: TimelineTrackView, didRequestTimelineExtensionTo newDuration: Double) {
        resizeTimeline(to: newDuration)
        delegate?.timelineView(self, didExtendDurationTo: newDuration)
    }

    func trackView(_ view: TimelineTrackView, didRequestTimelineShrinkTo newDuration: Double) {
        let safeDuration = max(newDuration, config.minimumProjectDuration)
        resizeTimeline(to: safeDuration)
        delegate?.timelineView(self, didExtendDurationTo: safeDuration)
    }

    func trackView(_ view: TimelineTrackView, didUpdateTrack track: MediaTrack) {
        if let index = currentTracks.firstIndex(where: { $0.id == track.id }) {
            currentTracks[index] = track
        } else {
            currentTracks.append(track)
        }

        // When the master (video) track changes, push the new duration
        // ceiling to every non-master lane so their clips stay within bounds.
        if view.trackType == .video {
            let masterEnd = track.clips.map(\.timelineRange.endSeconds).max()
            for lane in dynamicTrackViews where lane.trackType != .video {
                lane.updateDurationLimit(masterEnd)
                if let updated = lane.currentTrackSnapshot {
                    if let idx = currentTracks.firstIndex(where: { $0.id == updated.id }) {
                        currentTracks[idx] = updated
                    }
                }
            }
        }

        delegate?.timelineView(self, didUpdateTracks: currentTracks)
    }

    func trackView(_ view: TimelineTrackView, masterReorderTransitionWarningVisible: Bool) {
        guard view.trackType == .video else { return }
        reorderClipsWarningLabel.isHidden = !masterReorderTransitionWarningVisible
        updateVerticalScrollingState()
    }

    func trackView(
        _ view: TimelineTrackView,
        didRequestTransitionPickerAfterClipAt clipIndex: Int,
        currentTransition: ClipTransition?
    ) {
        guard view.trackType == .video else { return }
        delegate?.timelineView(
            self,
            didRequestTransitionPickerAfterClipAt: clipIndex,
            currentTransition: currentTransition
        )
    }

    private func resizeTimeline(to duration: Double) {
        let tracksWidth = timelineLayout.xPosition(forSeconds: duration)
        let rulerWidth  = tracksWidth + (config.horizontalEdgePadding * 2)

        tracksContentWidthConstraint?.constant = tracksWidth
        rulerContentWidthConstraint?.constant  = rulerWidth

        rulerView.setNeedsDisplay()
        layoutIfNeeded()
    }
}
