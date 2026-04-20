//
// TimelineConfiguration
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Single source of truth for visual & behavioural constants used across the timeline
//  layer (ruler, tracks, clips, handles) and related editor chrome (e.g. canvas background swatches).
//
//  Usage:  TimelineConfiguration.default.<property>
//

import UIKit

struct TimelineConfiguration {

    // MARK: - Scale & Duration

    /// Horizontal zoom level: how many points represent one second.
    let pixelsPerSecond: CGFloat = 80

    /// Number of thumbnail tiles generated for each second of video/image.
    let thumbnailsPerSecond: Int = 2

    /// The ruler always shows at least this many seconds, even for short projects.
    let minimumProjectDuration: Double = EditorTimelinePolicy.default.minimumVisibleProjectDuration

    /// The shortest a clip can ever be (in seconds). Enforced by trim handles.
    let minClipDuration: Double = EditorTimelinePolicy.default.minClipDuration

    /// Default duration assigned to newly added images (in seconds).
    let preferredImageDuration: Double = EditorTimelinePolicy.default.preferredImageDuration
    let preferredStickerDuration: Double = EditorTimelinePolicy.default.preferredStickerDuration
    let preferredTextDuration: Double = EditorTimelinePolicy.default.preferredTextDuration

    // MARK: - Track Layout

    let rulerHeight: CGFloat = 28
    let trackPadding: CGFloat = 8
    let trackSpacing: CGFloat = 6

    /// Extra inset on each side of the ruler so "0s" / last-second labels
    /// don't clip against the scroll-view edge.
    let horizontalEdgePadding: CGFloat = 20

    let trackLaneCornerRadius: CGFloat = 6
    let videoLaneHeight: CGFloat = 60
    let audioLaneHeight: CGFloat = 36
    let overlayLaneHeight: CGFloat = 36
    let backgroundColor: UIColor = .secondarySystemBackground
    let warningLabelTextColor: UIColor = .systemYellow

    // MARK: - Clip Appearance

    let clipCornerRadius: CGFloat = 10
    let selectionHandleWidth: CGFloat = 20
    let selectionBorderWidth: CGFloat = 2

    /// Tappable control at the trailing inner edge of a master-track clip (before the trim handle).
    let masterTransitionAffordanceSize: CGFloat = 24

    // MARK: - Colors

    struct TitleShadow {
        let color: CGColor = UIColor.black.cgColor
        let offset: CGSize = CGSize(width: 0, height: 1)
        let radius: CGFloat = 2
        let opacity: Float = 0.9
    }

    let selectionColor = UIColor(red: 0.82, green: 0.67, blue: 0.00, alpha: 1.0)

    let videoTrackColor = UIColor.systemBlue.withAlphaComponent(0.15)
    let videoTilePlaceholderColor = UIColor.systemBlue.withAlphaComponent(0.25)

    let imageTrackColor = UIColor.systemBlue.withAlphaComponent(0.15)
    let imageTilePlaceholderColor = UIColor.systemBlue.withAlphaComponent(0.25)

    let audioTrackColor = UIColor.systemPurple
    let textTrackColor = UIColor.systemGreen.withAlphaComponent(0.35)
    let stickerTrackColor = UIColor.systemGreen.withAlphaComponent(0.2)

    let trackLaneBackgroundColor = UIColor.tertiarySystemBackground
    let trackTitleFont: UIFont = .systemFont(ofSize: 14, weight: .semibold)
    let trackTitleTextColor: UIColor = .white.withAlphaComponent(0.92)
    let trackTitleShadow: TitleShadow = TitleShadow()

    let reorderInsertionGuideLineWidth: CGFloat = 6
    let reorderInsertionGuideLineColor: UIColor = .systemYellow

    /// Strip under the video lane while reordering (when a transition warning is shown).
    let masterTrackReorderWarningStripHeight: CGFloat = 30

    // MARK: - Canvas background sheet (text color swatch parity)

    /// Solid and gradient presets in `CanvasBackgroundBottomSheetViewController`: 44pt square, corner 22.
    enum CanvasBackgroundSwatchLayout {
        static let side: CGFloat = 44
        static let cornerRadius: CGFloat = 22
    }

    // MARK: - Helpers

    func laneHeight(for trackType: MediaTrack.TrackType) -> CGFloat {
        switch trackType {
            case .video:   return videoLaneHeight
            case .audio:   return audioLaneHeight
            case .overlay: return overlayLaneHeight
        }
    }

    /// The total pixel height the timeline occupies.
    /// Expose as a static constant so EditorViewController can set a matching constraint.
    func preferredHeight() -> CGFloat {
        return rulerHeight
        + trackPadding
        + audioLaneHeight
        + trackSpacing
        + videoLaneHeight
        + trackPadding
    }

    // MARK: - Shared Instance

    static let `default` = TimelineConfiguration()
}
