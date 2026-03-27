//
//  TimelineTrackView.swift
//  VideoEditor
//
//  A single horizontal track lane inside the timeline scroll view.
//  Renders each MediaClip as a positioned, colored block.
//  Frame-based layout is intentional: clip positions derive from
//  time values, not from parent bounds, so Auto Layout adds nothing here.
//

import UIKit

// MARK: - Delegate

protocol TimelineTrackViewDelegate: AnyObject {
    /// Fired when the user taps a clip block in this track lane.
    func trackView(_ view: TimelineTrackView, didTapClipAt index: Int, mediaType: AssetIdentifier.MediaType)
    /// Fired when a clip extends beyond the current track width, requesting the timeline to grow.
    func trackView(_ view: TimelineTrackView, didRequestTimelineExtensionTo newDuration: Double)
}

// MARK: - TimelineTrackView

final class TimelineTrackView: UIView {
    // MARK: - Public

    let trackType: MediaTrack.TrackType
    weak var delegate: TimelineTrackViewDelegate?

    // MARK: - Private

    private var clipViews: [UIView] = []
    private var pixelsPerSecond: CGFloat = 80
    private var currentTrack: MediaTrack?
    private var maxTrackDuration: Double = 0
    private let thumbnailGenerator: ThumbnailGenerating
    private weak var selectedMediaView: TrackMediaView?

    // MARK: - Init

    init(trackType: MediaTrack.TrackType, thumbnailGenerator: ThumbnailGenerating) {
        self.trackType = trackType
        self.thumbnailGenerator = thumbnailGenerator
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

    // MARK: - Configuration

    func configure(with track: MediaTrack?, pixelsPerSecond pxPerSec: CGFloat) {
        self.pixelsPerSecond = pxPerSec
        self.currentTrack = track
        self.maxTrackDuration = max(Double(bounds.width / max(pxPerSec, 1)), 0)

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
        maxTrackDuration = max(Double(bounds.width / max(pixelsPerSecond, 1)), 0)
        clipViews.forEach {
            guard let mediaView = $0 as? TrackMediaView else { return }
            mediaView.updateTrackLimits(maxDuration: maxTrackDuration)
            mediaView.frame.size.height = trackContentHeight
        }
    }

    // MARK: - Private Helpers

    private var trackContentHeight: CGFloat { bounds.height }

    private func makeClipView(for clip: MediaClip, at index: Int) -> UIView {
        let xPos   = CGFloat(clip.timelineRange.startSeconds)    * pixelsPerSecond
        let width  = CGFloat(clip.timelineRange.durationSeconds) * pixelsPerSecond
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
        mediaView.updateTrackLimits(maxDuration: maxTrackDuration)
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
                pixelsPerSecond: pixelsPerSecond,
                thumbnailGenerator: thumbnailGenerator
            )
        case .audio:
            return AudioTrackMediaView(
                frame: frame,
                clip: clip,
                pixelsPerSecond: pixelsPerSecond
            )
        case .image:
            return ImageTrackMediaView(
                frame: frame,
                clip: clip,
                pixelsPerSecond: pixelsPerSecond,
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
            return
        }

        selectedMediaView?.setSelected(false)
        selectedMediaView = view
        view.setSelected(true)

        let clips = currentTrack?.clips ?? []
        let mediaType = clips.indices.contains(view.tag) ? clips[view.tag].asset.mediaType : .video
        delegate?.trackView(self, didTapClipAt: view.tag, mediaType: mediaType)
    }

    func trackMediaView(_ view: TrackMediaView, didChangeTimelineRange range: ClipTimeRange) {
        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(view.tag) else { return }
        track.clips[view.tag].timelineRange = range
        currentTrack = track

        resolveCollisions(from: view)
        requestTimelineExtensionIfNeeded()
    }

    // MARK: - Collision Resolution

    /// Ensures no two clips overlap after a clip is moved or resized.
    /// Pushes neighbours outward from the edited clip; clamps leftward pushes at x = 0,
    /// then re-checks left-to-right so clamping doesn't leave residual overlaps.
    private func resolveCollisions(from movedView: TrackMediaView) {
        let mediaViews = clipViews.compactMap { $0 as? TrackMediaView }
        guard mediaViews.count > 1 else { return }

        let sorted = mediaViews.sorted { $0.frame.minX < $1.frame.minX }
        guard let movedIndex = sorted.firstIndex(where: { $0 === movedView }) else { return }

        // 1) Push clips to the RIGHT of the moved clip
        for i in movedIndex ..< (sorted.count - 1) {
            let current = sorted[i]
            let next    = sorted[i + 1]
            if current.frame.maxX > next.frame.minX {
                next.frame.origin.x = current.frame.maxX
                updateClipRange(for: next)
            }
        }

        // 2) Push clips to the LEFT of the moved clip (clamped at 0)
        for i in stride(from: movedIndex, through: 1, by: -1) {
            let current = sorted[i]
            let prev    = sorted[i - 1]
            if prev.frame.maxX > current.frame.minX {
                let newX = max(current.frame.minX - prev.frame.width, 0)
                prev.frame.origin.x = newX
                updateClipRange(for: prev)
            }
        }

        // 3) Final left-to-right pass: clamping at 0 may have left new overlaps
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
        let newStart  = Double(view.frame.origin.x / pixelsPerSecond)
        let duration  = Double(view.frame.width / pixelsPerSecond)
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

        let newDuration = Double(maxEndPx / pixelsPerSecond)
        delegate?.trackView(self, didRequestTimelineExtensionTo: newDuration)
    }
}
