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

        clipViews.forEach { $0.removeFromSuperview() }
        clipViews.removeAll()

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
        // Re-apply clip view heights whenever the track itself is resized.
        clipViews.forEach { $0.frame.size.height = trackContentHeight }
    }

    // MARK: - Private Helpers

    private var trackContentHeight: CGFloat { bounds.height - 8 }

    private func makeClipView(for clip: MediaClip, at index: Int) -> UIView {
        let xPos   = CGFloat(clip.timelineRange.startSeconds)    * pixelsPerSecond
        let width  = CGFloat(clip.timelineRange.durationSeconds) * pixelsPerSecond
        // Guard against 0-duration clips (e.g. freshly imported stills before user edits).
        let safeW  = max(width, 48)

        let v = UIView(frame: CGRect(
            x:      xPos,
            y:      4,
            width:  safeW,
            height: trackContentHeight
        ))
        v.backgroundColor    = kind.clipColor.withAlphaComponent(0.85)
        v.layer.cornerRadius  = 8
        v.layer.masksToBounds = true
        // Tag carries the clip index so the tap handler can look up which clip was tapped.
        v.tag = index
        v.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleClipTap(_:)))
        v.addGestureRecognizer(tap)

        if kind == .video {
            v.layer.borderColor = UIColor.systemYellow.cgColor
            v.layer.borderWidth = 2
            addThumbnailStripes(to: v)
        } else {
            addAudioHighlight(to: v)
        }

        return v
    }

    /// Decorative vertical stripe pattern that simulates thumbnail columns.
    /// Replaced by real AVAssetImageGenerator thumbnails in a later phase.
    private func addThumbnailStripes(to view: UIView) {
        let stripeW:   CGFloat = 2
        let stripeGap: CGFloat = 30
        var x: CGFloat = stripeGap

        while x < view.bounds.width - stripeW {
            let stripe = UIView(frame: CGRect(x: x, y: 0, width: stripeW, height: view.bounds.height))
            stripe.backgroundColor = UIColor.black.withAlphaComponent(0.18)
            stripe.autoresizingMask = [.flexibleHeight]
            stripe.isUserInteractionEnabled = false
            view.addSubview(stripe)
            x += stripeGap
        }
    }

    /// Semi-transparent white band at the top of the audio block for visual depth.
    private func addAudioHighlight(to view: UIView) {
        let highlight = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 6))
        highlight.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        highlight.autoresizingMask = [.flexibleWidth]
        highlight.isUserInteractionEnabled = false
        view.addSubview(highlight)
    }

    // MARK: - Tap Handler

    @objc private func handleClipTap(_ gesture: UITapGestureRecognizer) {
        guard let v = gesture.view else { return }
        delegate?.trackView(self, didTapClipAt: v.tag)
    }
}
