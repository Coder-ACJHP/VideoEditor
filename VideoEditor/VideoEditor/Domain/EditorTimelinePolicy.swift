//
// EditorTimelinePolicy
// VideoEditor
//

import Foundation

/// Duration and trimming limits shared by the editing model and the timeline UI.
/// Lives in **Domain** so presentation and data layers do not define each other’s rules.
struct EditorTimelinePolicy: Sendable {

    static let `default` = EditorTimelinePolicy()

    /// Shortest clip length enforced when trimming, duplicating, or import fallbacks.
    let minClipDuration: Double = 1.0

    /// Minimum span for ruler width and empty-project layout (seconds).
    let minimumVisibleProjectDuration: Double = 3.0

    let preferredImageDuration: Double = 3.0
    let preferredStickerDuration: Double = 2.0
    let preferredTextDuration: Double = 2.0
}
