//
// MediaClip
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Placement of a source media segment on the composition timeline and effects to apply.
//
//  Why two time spaces?
//  - timelineRange: where the clip sits on the composition and how long it is visible.
//  - sourceRange:    which portion of the source asset to use (trim window).
//  This split maps directly to AVCompositionTrackSegment.timeMapping and supports
//  advanced features such as speed ramping.

import Foundation

nonisolated struct MediaClip: Identifiable, Sendable {

    let id: UUID

    /// Media source and kind for this clip.
    let asset: AssetIdentifier

    /// Position on the composition timeline and visible duration.
    var timelineRange: ClipTimeRange

    /// Portion of the source asset to use (trim window). The engine ignores this for image / text assets.
    var sourceRange: ClipTimeRange

    /// Normalized placement on the canvas / composition (shared by all visual clip kinds).
    var transform: TransformEffect

    /// Transition from this clip into the next at this clip's end. `nil` = hard cut.
    var transitionOut: ClipTransition?

    /// Ordered effect list; application order affects the rendered result. Often empty for now.
    var effects: [EffectConfiguration]

    /// Opacity on overlay tracks. 0.0 = fully transparent, 1.0 = opaque.
    var opacity: Float

    // MARK: - Constants

    /// Default on-timeline duration for image clips. The UI uses this when adding a photo; the user can trim later.
    static var defaultImageDuration: Double { EditorTimelinePolicy.default.preferredImageDuration }

    // MARK: - Init (Video / Audio)

    /// General initializer for video or audio clips.
    init(
        id: UUID = UUID(),
        asset: AssetIdentifier,
        timelineRange: ClipTimeRange,
        sourceRange: ClipTimeRange,
        transitionOut: ClipTransition? = nil,
        effects: [EffectConfiguration] = [],
        transform: TransformEffect = .identity,
        opacity: Float = 1.0
    ) {
        self.id = id
        self.asset = asset
        self.timelineRange = timelineRange
        self.sourceRange = sourceRange
        self.transitionOut = transitionOut
        self.effects = effects
        self.transform = transform
        self.opacity = opacity
    }

    // MARK: - Init (Image)

    /// Convenience initializer for a still image (or text-as-still) asset.
    /// `sourceRange` is zeroed because still frames have no meaningful source trim.
    /// - Parameters:
    ///   - imageAsset: Use `.image`, `.phAssetImage`, or `.text` (single frame).
    ///   - timelineOffset: Start time on the timeline (seconds).
    ///   - duration: Visible duration; defaults to `defaultImageDuration` (3 seconds).
    init(
        id: UUID = UUID(),
        imageAsset: AssetIdentifier,
        timelineOffset: Double,
        duration: Double = MediaClip.defaultImageDuration,
        transitionOut: ClipTransition? = nil,
        transform: TransformEffect = .identity,
        opacity: Float = 1.0
    ) {
        self.id = id
        self.asset = imageAsset
        self.timelineRange = ClipTimeRange(startSeconds: timelineOffset, durationSeconds: duration)
        // Source time range is meaningless for stills; start at zero.
        self.sourceRange = ClipTimeRange(startSeconds: 0, durationSeconds: duration)
        self.transitionOut = transitionOut
        self.effects = []
        self.transform = transform
        self.opacity = opacity
    }
}

// MARK: - Codable

extension MediaClip: Codable {

    private enum CodingKeys: String, CodingKey {
        case id
        case asset
        case timelineRange
        case sourceRange
        case transform
        case transitionOut
        case effects
        case opacity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        asset = try c.decode(AssetIdentifier.self, forKey: .asset)
        timelineRange = try c.decode(ClipTimeRange.self, forKey: .timelineRange)
        sourceRange = try c.decode(ClipTimeRange.self, forKey: .sourceRange)
        transform = try c.decodeIfPresent(TransformEffect.self, forKey: .transform) ?? .identity
        transitionOut = try c.decodeIfPresent(ClipTransition.self, forKey: .transitionOut)
        effects = try c.decodeIfPresent([EffectConfiguration].self, forKey: .effects) ?? []
        opacity = try c.decodeIfPresent(Float.self, forKey: .opacity) ?? 1.0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(asset, forKey: .asset)
        try c.encode(timelineRange, forKey: .timelineRange)
        try c.encode(sourceRange, forKey: .sourceRange)
        try c.encode(transform, forKey: .transform)
        try c.encodeIfPresent(transitionOut, forKey: .transitionOut)
        try c.encode(effects, forKey: .effects)
        try c.encode(opacity, forKey: .opacity)
    }
}

extension MediaClip: Equatable {}
