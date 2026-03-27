//
//  TimelineConfiguration.swift
//  VideoEditor
//
//  Single source of truth for every visual & behavioural constant
//  used across the timeline layer (ruler, tracks, clips, handles).
//
//  Usage:  TimelineConfiguration.default.<property>
//

import UIKit

struct TimelineConfiguration {

    // MARK: - Scale & Duration

    /// Horizontal zoom level: how many points represent one second.
    var pixelsPerSecond: CGFloat = 80

    /// Number of thumbnail tiles generated for each second of video/image.
    var thumbnailsPerSecond: Int = 1

    /// The ruler always shows at least this many seconds, even for short projects.
    var minimumProjectDuration: Double = 3.0

    /// The shortest a clip can ever be (in seconds). Enforced by trim handles.
    var minClipDuration: Double = 1.0

    /// Default duration assigned to newly added images (in seconds).
    var preferredImageDuration: Double = 5.0

    // MARK: - Track Layout

    var rulerHeight: CGFloat = 28
    var trackPadding: CGFloat = 8
    var trackSpacing: CGFloat = 6

    /// Extra inset on each side of the ruler so "0s" / last-second labels
    /// don't clip against the scroll-view edge.
    var horizontalEdgePadding: CGFloat = 20

    var trackLaneCornerRadius: CGFloat = 6
    var videoLaneHeight: CGFloat = 60
    var audioLaneHeight: CGFloat = 36
    var overlayLaneHeight: CGFloat = 36

    // MARK: - Clip Appearance

    var clipCornerRadius: CGFloat = 10
    var selectionHandleWidth: CGFloat = 20
    var selectionBorderWidth: CGFloat = 2

    /// Tappable control at the trailing inner edge of a master-track clip (before the trim handle).
    var masterTransitionAffordanceSize: CGFloat = 24

    // MARK: - Colors

    var selectionColor = UIColor(red: 0.82, green: 0.67, blue: 0.00, alpha: 1.0)

    var videoTrackColor = UIColor.systemBlue.withAlphaComponent(0.15)
    var videoTilePlaceholderColor = UIColor.systemBlue.withAlphaComponent(0.25)

    var imageTrackColor = UIColor.systemBlue.withAlphaComponent(0.15)
    var imageTilePlaceholderColor = UIColor.systemBlue.withAlphaComponent(0.25)

    var audioTrackColor = UIColor.systemPurple.withAlphaComponent(0.35)
    var textTrackColor = UIColor.systemGreen.withAlphaComponent(0.35)
    var stickerTrackColor = UIColor.systemGreen.withAlphaComponent(0.2)

    var trackLaneBackgroundColor = UIColor.tertiarySystemBackground

    // MARK: - Helpers

    func laneHeight(for trackType: MediaTrack.TrackType) -> CGFloat {
        switch trackType {
            case .video:   return videoLaneHeight
            case .audio:   return audioLaneHeight
            case .overlay: return overlayLaneHeight
        }
    }

    // MARK: - Shared Instance

    static let `default` = TimelineConfiguration()
}
