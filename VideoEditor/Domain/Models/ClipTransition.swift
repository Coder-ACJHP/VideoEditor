//
// ClipTransition
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Single transition definition: project model (`MediaClip.transitionOut`), UI, and preview share this type.
//  clip[i].transitionOut is between clip[i] and clip[i+1]. nil = hard cut.
//  Preview compositing: `Engine/Extensions/ClipTransition+PreviewRendering.swift`.

import Foundation

nonisolated struct ClipTransition: Codable, Equatable {

    var type: TransitionType

    /// Target transition window in seconds. Clip durations on the timeline model stay unchanged;
    /// the preview engine maps this to overlap in composition time.
    var durationSeconds: Double

    enum TransitionType: String, Codable, CaseIterable {
        /// `CIDisintegrateWithMaskTransition` — mask image (see `ClipTransition+PreviewRendering`).
        case disintegrate
        case disintegrateHeart // Heart mask
        case disintegrateTiles // Tile mask
        /// `CISwipeTransition` — Transitions from one image to another by simulating a swiping action.
        case swipe
        /// `CIRippleTransition` — preview builds a shading image for the ripple surface.
        case ripple
        /// `CIModTransition` — modulation / wave (same parameters as presenting).
        case mod
        /// Incoming clip slides in over the outgoing clip.
        case slide
        /// `CIBarsSwipeTransition` — bar swipe (same image order as presenting direction).
        case barsSwipe
        /// Cross-dissolve; simplest to implement first.
        case crossDissolve
        /// `CICopyMachineTransition` — copy-machine scan (same parameters as presenting).
        case copyMachine
        /// Incoming clip pushes the outgoing clip left to right.
        case push
        /// `CIFlashTransition` — flash burst (center = frame center; default white).
        case flash
        /// `CIPageCurlWithShadowTransition` — page curl with shadow (see `ClipTransition+PreviewRendering`).
        case pageCurl
        /// `CIAccordionFoldTransition` — accordion fold between clips (see `ClipTransition+PreviewRendering`).
        case accordionFold
        /// Fade to black, then reveal the incoming clip.
        case fadeToBlack
    }

    // MARK: - Defaults

    /// Default: 0.5s cross-dissolve.
    static let `default` = ClipTransition(type: .crossDissolve, durationSeconds: 0.5)

    /// Safe overlap in seconds for adjacent clips given their timeline durations (preview / export).
    func resolvedOverlapSeconds(outgoingTimelineDuration: Double, incomingTimelineDuration: Double) -> Double {
        let cap = min(outgoingTimelineDuration * 0.45, incomingTimelineDuration * 0.45)
        return min(max(0, durationSeconds), max(0, cap))
    }
}
