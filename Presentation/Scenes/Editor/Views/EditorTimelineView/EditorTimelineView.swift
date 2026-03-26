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
    /// Fired when the user taps a clip block. Use the kind to build a context sub menu.
    func timelineView(_ timeline: EditorTimelineView, didSelectTrackKind kind: TimelineTrackView.Kind)
}

// MARK: - EditorTimelineView

final class EditorTimelineView: UIView {

    // MARK: - Layout Constants

    private enum Layout {
        static let pixelsPerSecond: CGFloat  = 80
        static let rulerHeight:     CGFloat  = 28
        static let trackPadding:    CGFloat  = 8   // top and bottom space inside scroll area
        static let trackSpacing:    CGFloat  = 6   // gap between audio and video tracks
        static let horizontalEdgePadding: CGFloat = 20 // ruler-only edge safety for labels
        static let minimumDuration: Double   = 10  // always show at least 10 s of ruler
    }

    /// The total pixel height the timeline occupies.
    /// Expose as a static constant so EditorViewController can set a matching constraint.
    static let preferredHeight: CGFloat = {
        Layout.rulerHeight
        + Layout.trackPadding
        + TimelineTrackView.Kind.audio.height
        + Layout.trackSpacing
        + TimelineTrackView.Kind.video.height
        + Layout.trackPadding
    }()

    // MARK: - Public

    weak var delegate: EditorTimelineViewDelegate?

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
        sv.spacing = Layout.trackSpacing
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    private let playheadView = TimelinePlayheadView()

    // MARK: - State

    /// Backing constraints for timeline width; replaced when project duration changes.
    private var rulerContentWidthConstraint: NSLayoutConstraint?
    private var tracksContentWidthConstraint: NSLayoutConstraint?

    /// Runtime-created lanes (audio/video/overlay). Rebuilt on every configure call.
    private var dynamicTrackViews: [TimelineTrackView] = []

    /// Prevents the scrub-delegate callback from firing when we move the offset programmatically.
    private var isSettingTimeExternally = false

    /// Set once after the first valid layout pass to avoid resetting contentOffset on rotation.
    private var hasAppliedInitialOffset = false

    // MARK: - Init

    override init(frame: CGRect) {
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
        NSLayoutConstraint.activate([
            rulerScrollView.topAnchor.constraint(equalTo: topAnchor),
            rulerScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rulerScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rulerScrollView.heightAnchor.constraint(equalToConstant: Layout.rulerHeight),
        ])
    }

    private func setupTracksScrollView() {
        tracksScrollView.delegate = self
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

        let initialWidth = CGFloat(Layout.minimumDuration) * Layout.pixelsPerSecond + (Layout.horizontalEdgePadding * 2)
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

        let initialWidth = CGFloat(Layout.minimumDuration) * Layout.pixelsPerSecond
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
        rulerView.pixelsPerSecond = Layout.pixelsPerSecond
        rulerContentView.addSubview(rulerView)
        NSLayoutConstraint.activate([
            rulerView.topAnchor.constraint(equalTo: rulerContentView.topAnchor),
            rulerView.leadingAnchor.constraint(equalTo: rulerContentView.leadingAnchor, constant: Layout.horizontalEdgePadding),
            rulerView.trailingAnchor.constraint(equalTo: rulerContentView.trailingAnchor, constant: -Layout.horizontalEdgePadding),
            rulerView.bottomAnchor.constraint(equalTo: rulerContentView.bottomAnchor),
        ])
    }

    private func setupTracksStack() {
        tracksContentView.addSubview(tracksStackView)
        NSLayoutConstraint.activate([
            tracksStackView.leadingAnchor.constraint(equalTo: tracksContentView.leadingAnchor),
            tracksStackView.trailingAnchor.constraint(equalTo: tracksContentView.trailingAnchor),
            tracksStackView.topAnchor.constraint(greaterThanOrEqualTo: tracksContentView.topAnchor, constant: Layout.trackPadding),
            tracksStackView.bottomAnchor.constraint(lessThanOrEqualTo: tracksContentView.bottomAnchor, constant: -Layout.trackPadding),
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
            rulerScrollView.contentOffset = CGPoint(x: Layout.horizontalEdgePadding - half, y: 0)
        }
    }

    // MARK: - Public API

    /// Populates the timeline from the project model.
    /// Safe to call multiple times (e.g. after adding / removing clips).
    func configure(with project: EditingProject) {
        let duration = max(project.totalDuration.seconds, Layout.minimumDuration)
        let tracksTimelineWidth = CGFloat(duration) * Layout.pixelsPerSecond
        let rulerTimelineWidth = tracksTimelineWidth + (Layout.horizontalEdgePadding * 2)
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
        let x = CGFloat(seconds) * Layout.pixelsPerSecond - half
        isSettingTimeExternally = true
        let y = tracksScrollView.contentOffset.y
        let offset = CGPoint(x: x, y: y)
        tracksScrollView.setContentOffset(offset, animated: false)
        rulerScrollView.setContentOffset(CGPoint(x: x + Layout.horizontalEdgePadding, y: 0), animated: false)
        isSettingTimeExternally = false
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
            let kind: TimelineTrackView.Kind
            let model: MediaTrack?

            if let track = maybeTrack {
                kind = track.displayKind
                model = track
            } else {
                // Placeholder lanes keep base timeline structure always visible.
                kind = dynamicTrackViews.contains(where: { $0.kind == .audio }) ? .video : .audio
                model = nil
            }

            let lane = TimelineTrackView(kind: kind)
            lane.delegate = self
            lane.heightAnchor.constraint(equalToConstant: kind.height).isActive = true
            lane.configure(with: model, pixelsPerSecond: Layout.pixelsPerSecond)
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
        ).height + (Layout.trackPadding * 2)
        let visibleHeight = tracksScrollView.bounds.height
        let needsVerticalScroll = contentHeight > visibleHeight
        tracksScrollView.alwaysBounceVertical = needsVerticalScroll
        tracksScrollView.showsVerticalScrollIndicator = needsVerticalScroll
    }
}

// MARK: - UIScrollViewDelegate

extension EditorTimelineView: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isSettingTimeExternally else { return }
        guard scrollView === tracksScrollView else { return }

        isSettingTimeExternally = true
        rulerScrollView.contentOffset.x = tracksScrollView.contentOffset.x + Layout.horizontalEdgePadding
        isSettingTimeExternally = false

        // contentOffset.x == -contentInset.left  →  time 0 is under the playhead.
        let rawOffset = tracksScrollView.contentOffset.x + tracksScrollView.contentInset.left
        let time = max(Double(rawOffset / Layout.pixelsPerSecond), 0)
        delegate?.timelineView(self, didScrubToTime: time)
    }
}

// MARK: - TimelineTrackViewDelegate

extension EditorTimelineView: TimelineTrackViewDelegate {

    func trackView(_ view: TimelineTrackView, didTapClipAt index: Int) {
        delegate?.timelineView(self, didSelectTrackKind: view.kind)
    }
}

// MARK: - MediaTrack convenience

private extension MediaTrack {
    /// Convenience alias so the timeline can ask for track kind without
    /// caring about the full TrackType enum used by the domain model.
    var kind: TimelineTrackView.Kind? {
        switch trackType {
        case .video:   return .video
        case .audio:   return .audio
        case .overlay: return nil   // handled separately in a future phase
        }
    }

    var displayKind: TimelineTrackView.Kind {
        switch trackType {
        case .video: return .video
        case .audio: return .audio
        case .overlay: return .video
        }
    }
}
