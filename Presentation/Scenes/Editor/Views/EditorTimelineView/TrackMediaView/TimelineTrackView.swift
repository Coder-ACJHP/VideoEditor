//
//  TimelineTrackView.swift
//  VideoEditor
//
//  A single horizontal track lane inside the timeline scroll view.
//  Renders each MediaClip as a positioned, colored block.
//  Frame-based layout is intentional: clip positions derive from
//  time values, not from parent bounds, so Auto Layout adds nothing here.
//
//  Timeline behavior rules used in this file:
//  1) Master track is the `.video` lane and is the single source of truth
//     for project duration.
//  2) Master-track clips must stay contiguous (no gaps). After edits, clips
//     are packed edge-to-edge, first clip starts at t=0.
//  3) Master track can both extend and shrink the timeline based on its
//     rightmost clip end.
//  4) Non-master tracks do not control shrink. They resolve overlaps locally
//     and only request timeline extension when needed.
//  5) Master-track contiguity is computed in Domain (`TimelineArranging`); this view
//     applies the resulting `timelineRange` values to frames.
//

import UIKit

// MARK: - Delegate

protocol TimelineTrackViewDelegate: AnyObject {
    /// Fired when the user taps a clip block in this track lane.
    func trackView(_ view: TimelineTrackView, didTapClipAt index: Int, mediaType: AssetIdentifier.MediaType)
    /// Fired when the user deselects a clip (taps the same clip again).
    func trackViewDidDeselectClip(_ view: TimelineTrackView)
    /// Fired when a clip extends beyond the current track width, requesting the timeline to grow.
    func trackView(_ view: TimelineTrackView, didRequestTimelineExtensionTo newDuration: Double)
    /// Fired when the master (video) track's total duration shrinks after a trim.
    func trackView(_ view: TimelineTrackView, didRequestTimelineShrinkTo newDuration: Double)
    /// Fired whenever this lane's clip model changes due to drag/trim/collision updates.
    func trackView(_ view: TimelineTrackView, didUpdateTrack track: MediaTrack)
}

// MARK: - TimelineTrackView

final class TimelineTrackView: UIView {
    // MARK: - Public

    let trackType: MediaTrack.TrackType
    weak var delegate: TimelineTrackViewDelegate?

    /// Read-only snapshot of the current track model (after any live edits).
    var currentTrackSnapshot: MediaTrack? { currentTrack }

    // MARK: - Private

    private var clipViews: [UIView] = []
    private var layout: TimelineLayoutProvider = TimelineConfiguration.default.timelineLayout
    private var currentTrack: MediaTrack?
    private var maxTrackDuration: Double = 0
    private var durationLimitOverride: Double?
    private let thumbnailGenerator: ThumbnailGenerating
    private let timelineArranger: TimelineArranging
    private weak var selectedMediaView: TrackMediaView?

    // MARK: - Init

    init(
        trackType: MediaTrack.TrackType,
        thumbnailGenerator: ThumbnailGenerating,
        timelineArranger: TimelineArranging = MasterTrackTimelineArranger()
    ) {
        self.trackType = trackType
        self.thumbnailGenerator = thumbnailGenerator
        self.timelineArranger = timelineArranger
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TimelineConfiguration.default.trackLaneBackgroundColor
        layer.cornerRadius = TimelineConfiguration.default.trackLaneCornerRadius
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Selection

    func deselectAll() {
        selectedMediaView?.setSelected(false)
        selectedMediaView = nil
    }

    // MARK: - Duration Limit

    /// Pushes a new duration ceiling from the master track and clamps
    /// any clips whose right edge now exceeds that ceiling.
    func updateDurationLimit(_ limit: Double?) {
        durationLimitOverride = limit
        let ceiling = effectiveTrackDurationLimit
        let maxPx = layout.xPosition(forSeconds: ceiling)

        for view in clipViews.compactMap({ $0 as? TrackMediaView }) {
            view.updateTrackLimits(maxDuration: ceiling)
            guard view.frame.maxX > maxPx else { continue }

            let clampedWidth = max(maxPx - view.frame.origin.x, 0)
            let minW = layout.width(forDurationSeconds: TimelineConfiguration.default.minClipDuration)
            guard clampedWidth >= minW else { continue }

            view.frame.size.width = clampedWidth

            let duration = layout.seconds(forXPosition: clampedWidth)
            let range = ClipTimeRange(
                startSeconds: layout.seconds(forXPosition: view.frame.origin.x),
                durationSeconds: duration
            )
            view.applyTimelineRange(range)

            var src = view.sourceRange
            src.durationSeconds = duration
            view.applySourceRange(src)

            guard var track = currentTrack else { continue }
            guard track.clips.indices.contains(view.tag) else { continue }
            track.clips[view.tag].timelineRange = range
            track.clips[view.tag].sourceRange.durationSeconds = duration
            currentTrack = track
        }
    }

    // MARK: - Configuration

    func configure(
        with track: MediaTrack?,
        layout: TimelineLayoutProvider,
        durationLimitOverride: Double? = nil
    ) {
        self.layout = layout
        self.currentTrack = track
        self.durationLimitOverride = durationLimitOverride
        self.maxTrackDuration = layout.durationSeconds(forContentWidth: bounds.width)

        clipViews.forEach { $0.removeFromSuperview() }
        clipViews.removeAll()
        selectedMediaView = nil

        guard let track else { return }

        for (index, clip) in track.clips.enumerated() {
            let v = makeClipView(for: clip, at: index)
            addSubview(v)
            clipViews.append(v)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        maxTrackDuration = layout.durationSeconds(forContentWidth: bounds.width)
        clipViews.forEach {
            guard let mediaView = $0 as? TrackMediaView else { return }
            mediaView.updateTrackLimits(maxDuration: effectiveTrackDurationLimit)
            mediaView.frame.size.height = trackContentHeight
        }

        // Earlier master clips draw above later ones so the transition chip (centered on the seam) stays visible over the next clip.
        if trackType == .video {
            let n = clipViews.count
            for (i, v) in clipViews.enumerated() {
                v.layer.zPosition = CGFloat(n - 1 - i)
            }
        } else {
            clipViews.forEach { $0.layer.zPosition = 0 }
        }
    }

    // MARK: - Private Helpers

    private var trackContentHeight: CGFloat { bounds.height }
    private var effectiveTrackDurationLimit: Double { durationLimitOverride ?? maxTrackDuration }

    private func makeClipView(for clip: MediaClip, at index: Int) -> UIView {
        let xPos  = layout.xPosition(forSeconds: clip.timelineRange.startSeconds)
        let width = layout.width(forDurationSeconds: clip.timelineRange.durationSeconds)
        let safeW  = max(width, 48)
        let frame = CGRect(
            x:      xPos,
            y:      0,
            width:  safeW,
            height: trackContentHeight
        )

        let mediaView = makeMediaView(for: clip, frame: frame)
        mediaView.tag = index
        mediaView.delegate = self
        mediaView.isMasterTrack = (trackType == .video)
        let clipCount = currentTrack?.clips.count ?? 0
        let hasFollowingClip = index < clipCount - 1
        let isVisualMasterClip = trackType == .video
            && (clip.asset.mediaType == .video || clip.asset.mediaType == .image || clip.asset.mediaType == .text)
        mediaView.showsMasterTransitionAffordance = isVisualMasterClip && hasFollowingClip
        mediaView.updateTrackLimits(maxDuration: effectiveTrackDurationLimit)
        mediaView.setSelected(false)
        mediaView.applyTimelineRange(clip.timelineRange)

        return mediaView
    }

    private func makeMediaView(for clip: MediaClip, frame: CGRect) -> TrackMediaView {
        switch clip.asset.mediaType {
        case .video:
            return VideoTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout,
                thumbnailGenerator: thumbnailGenerator
            )
        case .audio:
            return AudioTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout
            )
        case .image:
            return ImageTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout,
                thumbnailGenerator: thumbnailGenerator
            )
        case .text:
            return TextTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout,
                thumbnailGenerator: thumbnailGenerator
            )
        }
    }
}

// MARK: - TrackMediaViewDelegate

extension TimelineTrackView: TrackMediaViewDelegate {
    func trackMediaViewDidToggleSelection(_ view: TrackMediaView) {
        if selectedMediaView === view {
            view.setSelected(false)
            selectedMediaView = nil
            delegate?.trackViewDidDeselectClip(self)
            return
        }

        selectedMediaView?.setSelected(false)
        selectedMediaView = view
        view.setSelected(true)

        let clips = currentTrack?.clips ?? []
        let mediaType = clips.indices.contains(view.tag) ? clips[view.tag].asset.mediaType : .video
        delegate?.trackView(self, didTapClipAt: view.tag, mediaType: mediaType)
    }

    func trackMediaViewDidTapTransitionAffordance(_ view: TrackMediaView) {
        guard trackType == .video else { return }
        guard let track = currentTrack else { return }
        guard track.clips.indices.contains(view.tag) else { return }
        guard view.tag < track.clips.count - 1 else { return }

        let clipIndex = view.tag
        guard let host = view.enclosingViewController() else { return }

        let current = track.clips[clipIndex].transitionOut
        let alert = UIAlertController(
            title: "Transition",
            message: "Applied between this clip and the next.",
            preferredStyle: .actionSheet
        )

        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            let s = TimelineConfiguration.default.masterTransitionAffordanceSize
            let cx = view.bounds.width
            pop.sourceRect = CGRect(x: cx - s / 2, y: view.bounds.midY - s / 2, width: s, height: s)
            pop.permittedArrowDirections = [.up, .down]
        }

        if current != nil {
            alert.addAction(UIAlertAction(title: "Remove transition", style: .destructive) { [weak self] _ in
                self?.applyTransitionOut(nil, forClipAt: clipIndex, mediaView: view)
            })
        }

        for transitionType in ClipTransition.TransitionType.allCases {
            let title = Self.displayTitle(for: transitionType)
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                let next = ClipTransition(type: transitionType, durationSeconds: ClipTransition.default.durationSeconds)
                self?.applyTransitionOut(next, forClipAt: clipIndex, mediaView: view)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        host.present(alert, animated: true)
    }

    func trackMediaView(_ view: TrackMediaView, didChangeTimelineRange range: ClipTimeRange, sourceRange: ClipTimeRange, allowExtension: Bool) {
        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(view.tag) else { return }
        track.clips[view.tag].timelineRange = range
        track.clips[view.tag].sourceRange = sourceRange
        currentTrack = track

        if trackType == .video {
            if allowExtension {
                applyMasterTrackContiguityFromDomain()
                requestTimelineResizeIfNeeded()
            }
        } else {
            resolveCollisions(from: view)
            if allowExtension {
                requestTimelineExtensionIfNeeded()
            }
        }

        notifyTrackUpdated()
    }

    // MARK: - Master Track Contiguity (Domain)

    /// Runs `TimelineArranging` on the current model, then syncs clip views from `timelineRange`.
    private func applyMasterTrackContiguityFromDomain() {
        guard var track = currentTrack else { return }
        track.clips = timelineArranger.enforceMasterTrackContiguity(clips: track.clips)
        currentTrack = track
        applyMasterTrackClipViewsFromModel()
    }

    private func applyMasterTrackClipViewsFromModel() {
        guard let track = currentTrack else { return }
        for index in track.clips.indices {
            guard index < clipViews.count,
                  let view = clipViews[index] as? TrackMediaView
            else { continue }

            let clip = track.clips[index]
            let x = layout.xPosition(forSeconds: clip.timelineRange.startSeconds)
            let w = layout.width(forDurationSeconds: clip.timelineRange.durationSeconds)
            let safeW = max(w, 48)

            view.frame.origin.x = x
            view.frame.size.width = safeW
            view.applyTimelineRange(clip.timelineRange)
        }
    }

    /// For the master track: extends OR shrinks the timeline to match the arranged model end.
    private func requestTimelineResizeIfNeeded() {
        guard let track = currentTrack, trackType == .video, !track.clips.isEmpty else { return }

        let maxEndSeconds = track.clips.map(\.timelineRange.endSeconds).max() ?? 0
        let maxEndPx = layout.xPosition(forSeconds: maxEndSeconds)
        let currentWidthPx = bounds.width
        let newDuration = maxEndSeconds

        if maxEndPx > currentWidthPx {
            delegate?.trackView(self, didRequestTimelineExtensionTo: newDuration)
        } else if maxEndPx < currentWidthPx {
            delegate?.trackView(self, didRequestTimelineShrinkTo: newDuration)
        }
    }

    // MARK: - Sub-Track Collision Resolution

    /// For non-master tracks: pushes neighbours apart to prevent overlap.
    private func resolveCollisions(from movedView: TrackMediaView) {
        let mediaViews = clipViews.compactMap { $0 as? TrackMediaView }
        guard mediaViews.count > 1 else { return }

        let sorted = mediaViews.sorted { $0.frame.minX < $1.frame.minX }
        guard let movedIndex = sorted.firstIndex(where: { $0 === movedView }) else { return }

        for i in movedIndex ..< (sorted.count - 1) {
            let current = sorted[i]
            let next    = sorted[i + 1]
            if current.frame.maxX > next.frame.minX {
                next.frame.origin.x = current.frame.maxX
                updateClipRange(for: next)
            }
        }

        for i in stride(from: movedIndex, through: 1, by: -1) {
            let current = sorted[i]
            let prev    = sorted[i - 1]
            if prev.frame.maxX > current.frame.minX {
                let newX = max(current.frame.minX - prev.frame.width, 0)
                prev.frame.origin.x = newX
                updateClipRange(for: prev)
            }
        }

        for i in 0 ..< (sorted.count - 1) {
            let current = sorted[i]
            let next    = sorted[i + 1]
            if current.frame.maxX > next.frame.minX {
                next.frame.origin.x = current.frame.maxX
                updateClipRange(for: next)
            }
        }
    }

    /// Syncs a pushed clip's frame back into its model range.
    private func updateClipRange(for view: TrackMediaView) {
        let newStart = layout.seconds(forXPosition: view.frame.origin.x)
        let duration = layout.seconds(forXPosition: view.frame.width)
        let range = ClipTimeRange(startSeconds: newStart, durationSeconds: duration)
        view.applyTimelineRange(range)

        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(view.tag) else { return }
        track.clips[view.tag].timelineRange = range
        currentTrack = track
    }

    /// If the rightmost clip exceeds the track's visible width, ask the parent to extend.
    private func requestTimelineExtensionIfNeeded() {
        let mediaViews = clipViews.compactMap { $0 as? TrackMediaView }
        guard let maxEndPx = mediaViews.map({ $0.frame.maxX }).max() else { return }

        let currentWidthPx = bounds.width
        guard maxEndPx > currentWidthPx else { return }

        let newDuration = layout.seconds(forXPosition: maxEndPx)
        delegate?.trackView(self, didRequestTimelineExtensionTo: newDuration)
    }

    private func notifyTrackUpdated() {
        guard let track = currentTrack else { return }
        delegate?.trackView(self, didUpdateTrack: track)
    }

    private func applyTransitionOut(_ transition: ClipTransition?, forClipAt index: Int, mediaView: TrackMediaView) {
        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(index) else { return }
        track.clips[index].transitionOut = transition
        currentTrack = track
        mediaView.applyTransitionOut(transition)
        notifyTrackUpdated()
    }

    private static func displayTitle(for type: ClipTransition.TransitionType) -> String {
        switch type {
        case .crossDissolve: return "Cross dissolve"
        case .fadeToBlack: return "Fade to black"
        case .push: return "Push"
        case .slide: return "Slide"
        }
    }
}

// MARK: - Responder chain (transition sheet presentation)

private extension UIView {
    func enclosingViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let vc = current as? UIViewController { return vc }
            responder = current.next
        }
        return nil
    }
}
