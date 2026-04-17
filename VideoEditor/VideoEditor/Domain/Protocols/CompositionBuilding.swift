//
// CompositionBuilding
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  EditingProject → AVFoundation preview / composition output contract.
//

import AVFoundation
import QuartzCore

/// Options that change how the composition is built (preview vs file export).
nonisolated struct CompositionBuildOptions: Sendable {

    /// When `true`, text clips on overlay tracks are rasterized into `AVVideoComposition` (export).
    /// Preview keeps this `false` so the editor can draw live text in UIKit.
    var includeTextOverlaysInVideoComposition: Bool = false

    static let previewDefault = CompositionBuildOptions()
    static let exportWithText = CompositionBuildOptions(includeTextOverlaysInVideoComposition: true)
}

/// Player item, composition, and video composition; all builders share this output shape.
struct CompositionBuildResult {
    let playerItem: AVPlayerItem
    let composition: AVComposition
    let videoComposition: AVVideoComposition
    /// Extra layers to stack on the player during preview (e.g. image track).
    let overlayLayers: [CALayer]
    /// Same mix applied to `playerItem`; required for `AVAssetExportSession`.
    let audioMix: AVAudioMix?
}

/// Abstraction that turns the project model into a playable composition.
/// Default preview implementation: `PreviewTimelineCompositionBuilder` in `Engine`; other engines can conform too.
protocol CompositionBuilding: AnyObject {

    func build(from project: EditingProject, options: CompositionBuildOptions) async throws -> CompositionBuildResult
}

extension CompositionBuilding {

    /// Preview build: no text baked into the video composition.
    func build(from project: EditingProject) async throws -> CompositionBuildResult {
        try await build(from: project, options: .previewDefault)
    }
}
