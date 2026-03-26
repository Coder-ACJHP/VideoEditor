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
    func trackView(_ view: TimelineTrackView, didTapClipAt index: Int)
}

// MARK: - TimelineTrackView

final class TimelineTrackView: UIView {

    // MARK: - Track Kind

    enum Kind {
        /// Primary video / image lane — tall, thumbnail-style blocks with a yellow border.
        case video
        /// Audio lane — slimmer, solid-color blocks.
        case audio

        var height: CGFloat {
            switch self {
            case .video: return 60
            case .audio: return 36
            }
        }

        /// Clip block fill color.
        var clipColor: UIColor {
            switch self {
            case .video: return .systemOrange
            case .audio: return .systemPurple
            }
        }

        /// Corresponding MediaTrack domain type(s).
        var trackTypes: [MediaTrack.TrackType] {
            switch self {
            case .video: return [.video]
            case .audio: return [.audio]
            }
        }
    }

    // MARK: - Public

    let kind: Kind
    weak var delegate: TimelineTrackViewDelegate?

    // MARK: - Private

    private var clipViews: [UIView] = []
    private var pixelsPerSecond: CGFloat = 80
    private var currentTrack: MediaTrack?
    private weak var selectedMediaView: TrackMediaView?
    private var maxTrackDuration: Double = 0

    // MARK: - Init

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .tertiarySystemBackground
        layer.cornerRadius = 6
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    /// Rebuilds the clip views from the given track model.
    /// Pass `nil` to show an empty lane (e.g. no audio has been added yet).
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
        // Re-apply clip view heights whenever the track itself is resized.
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
        // Guard against 0-duration clips (e.g. freshly imported stills before user edits).
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
            return VideoTrackMediaView(frame: frame, clip: clip, pixelsPerSecond: pixelsPerSecond)
        case .audio:
            return AudioTrackMediaView(frame: frame, clip: clip, pixelsPerSecond: pixelsPerSecond)
        case .image:
            // Image clips are represented as sticker-like visual blocks.
            return StickerTrackMediaView(frame: frame, clip: clip, pixelsPerSecond: pixelsPerSecond)
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
        delegate?.trackView(self, didTapClipAt: view.tag)
    }

    func trackMediaView(_ view: TrackMediaView, didChangeTimelineRange range: ClipTimeRange) {
        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(view.tag) else { return }
        track.clips[view.tag].timelineRange = range
        currentTrack = track
    }
}
