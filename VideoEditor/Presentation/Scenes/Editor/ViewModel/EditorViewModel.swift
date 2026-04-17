//
// EditorViewModel
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Owns working track state and editor session orchestration.
//  The view controller binds UI; domain rules for scratch clip insertion live here.
//

import AVFoundation
import CoreMedia
import Foundation

// MARK: - Delegate

@MainActor
protocol EditorViewModelDelegate: AnyObject {
    func editorViewModelDidRequestTimelineReload(_ viewModel: EditorViewModel)
    func editorViewModel(_ viewModel: EditorViewModel, didUpdateToolbarTotalDuration formatted: String)
}

// MARK: - ViewModel

@MainActor
final class EditorViewModel {

    weak var delegate: EditorViewModelDelegate?

    private let baseProject: EditingProject
    private var workingTracks: [MediaTrack]
    /// Mirrors `EditingProject.canvasBackground`.
    private var workingCanvasBackground: CanvasBackgroundSettings
    private let testMediaLocator: BundledTestMediaLocating
    private let timelineArranger: TimelineArranging

    /// Bump this whenever the preview composition must rebuild (`EditorPlaybackManager` observes it).
    private(set) var previewCompositionGeneration: UInt64 = 0

    /// Playhead on the shared project timeline (seconds). Updated by the view layer during scrub / playback.
    private(set) var currentPlaybackTimelineSeconds: Double = 0

    /// Full initializer for tests / custom dependencies.
    init(
        project: EditingProject,
        testMediaLocator: BundledTestMediaLocating,
        timelineArranger: TimelineArranging
    ) {
        self.baseProject = project
        self.workingTracks = project.tracks
        self.workingCanvasBackground = project.canvasBackground
        self.testMediaLocator = testMediaLocator
        self.timelineArranger = timelineArranger
    }

    /// App / router entry — default services are constructed on the main actor (not in a default argument).
    convenience init(project: EditingProject) {
        self.init(
            project: project,
            testMediaLocator: BundledTestMediaLocator(),
            timelineArranger: MasterTrackTimelineArranger()
        )
    }

    // MARK: - Navigation / chrome

    var projectDisplayName: String { baseProject.name }

    // MARK: - Lifecycle

    func start() {
        delegate?.editorViewModelDidRequestTimelineReload(self)
        delegate?.editorViewModel(self, didUpdateToolbarTotalDuration: formattedProjectEndTime())
    }

    func formattedScrubTime(seconds: Double) -> String {
        TimelineClockFormatter.string(fromSeconds: seconds)
    }

    func projectSnapshot() -> EditingProject {
        EditingProject(
            id: baseProject.id,
            name: baseProject.name,
            creationDate: baseProject.creationDate,
            lastModifiedDate: Date(),
            tracks: workingTracks,
            canvasBackground: workingCanvasBackground,
            exportSettings: baseProject.exportSettings
        )
    }

    // MARK: - Timeline sync

    /// Syncs timeline UI state into the model. Returns whether the preview `AVComposition` must reload
    /// (e.g. video/audio/overlay raster clips changed). Text-only timeline edits return `false`.
    @discardableResult
    func syncTracksFromTimeline(_ tracks: [MediaTrack]) -> Bool {
        let merged = Self.mergingAuthoritativeCanvasOverlayVisuals(
            baseline: workingTracks,
            timelineTracks: tracks
        )
        guard merged != workingTracks else { return false }
        let fingerprintBefore = previewCompositionFingerprintNow()
        workingTracks = merged
        let fingerprintAfter = previewCompositionFingerprintNow()
        if fingerprintBefore != fingerprintAfter {
            previewCompositionGeneration &+= 1
            return true
        }
        return false
    }

    func onMasterTimelineDurationChanged(seconds: Double) {
        delegate?.editorViewModel(
            self,
            didUpdateToolbarTotalDuration: TimelineClockFormatter.string(fromSeconds: seconds)
        )
    }

    /// Removes the clip everywhere it appears; repacks the master video track; drops empty tracks.
    func removeClip(withId clipId: UUID) {
        guard let (trackIndex, clipIndex) = trackAndClipIndex(for: clipId) else { return }
        let fingerprintBefore = previewCompositionFingerprintNow()
        var track = workingTracks[trackIndex]
        track.clips.remove(at: clipIndex)

        if track.trackType == .video, !track.clips.isEmpty {
            track.clips = timelineArranger.enforceMasterTrackContiguity(clips: track.clips)
        }

        if track.clips.isEmpty {
            workingTracks.remove(at: trackIndex)
        } else {
            workingTracks[trackIndex] = track
        }

        let fingerprintAfter = previewCompositionFingerprintNow()
        if fingerprintBefore != fingerprintAfter {
            previewCompositionGeneration &+= 1
        }
        publishTimelineAndToolbar()
    }

    /// Copies the selected clip onto a **new** track of the same type, matching the insert behavior used when
    /// adding media with `alwaysCreateNewTrack` (timeline starts at 0; source trim and visual state preserved).
    @discardableResult
    func duplicateClip(withId clipId: UUID) -> MediaClip? {
        guard let (trackIndex, clipIndex) = trackAndClipIndex(for: clipId) else { return nil }
        let sourceTrack = workingTracks[trackIndex]
        let sourceClip = sourceTrack.clips[clipIndex]
        let fingerprintBefore = previewCompositionFingerprintNow()

        let minDuration = EditorTimelinePolicy.default.minClipDuration
        let duration = max(sourceClip.timelineRange.durationSeconds, minDuration)
        let duplicated = MediaClip(
            id: UUID(),
            asset: sourceClip.asset,
            timelineRange: ClipTimeRange(startSeconds: 0, durationSeconds: duration),
            sourceRange: sourceClip.sourceRange,
            transitionOut: sourceClip.transitionOut,
            effects: sourceClip.effects,
            transform: sourceClip.transform,
            opacity: sourceClip.opacity
        )
        let newTrack = MediaTrack(
            trackType: sourceTrack.trackType,
            clips: [duplicated],
            isMuted: sourceTrack.isMuted,
            volume: sourceTrack.volume
        )
        workingTracks.append(newTrack)

        let fingerprintAfter = previewCompositionFingerprintNow()
        if fingerprintBefore != fingerprintAfter {
            previewCompositionGeneration &+= 1
        }
        publishTimelineAndToolbar()
        return duplicated
    }

    var canvasBackground: CanvasBackgroundSettings { workingCanvasBackground }

    func setCanvasBackground(_ settings: CanvasBackgroundSettings) {
        guard workingCanvasBackground != settings else { return }
        workingCanvasBackground = settings
        previewCompositionGeneration &+= 1
    }

    private func trackAndClipIndex(for clipId: UUID) -> (trackIndex: Int, clipIndex: Int)? {
        for (ti, t) in workingTracks.enumerated() {
            if let ci = t.clips.firstIndex(where: { $0.id == clipId }) {
                return (ti, ci)
            }
        }
        return nil
    }

    // MARK: - Features (scratch / dev inserts)

    /// Called after the user confirms the text sheet; appends a new overlay text clip.
    func addTextOverlay(with descriptor: TextOverlayDescriptor, transform: TransformEffect = .identity) async {
        await appendClip(to: .overlay, asset: .text(descriptor), duration: 3, initialTransform: transform)
    }

    /// Canvas gestures: updates `TransformEffect` for the matching overlay `MediaClip.id`.
    /// Preview raster overlays are UIKit-driven; composition fingerprint ignores their transforms.
    func updateOverlayTransform(clipId: UUID, transform: TransformEffect) {
        for trackIndex in workingTracks.indices where workingTracks[trackIndex].trackType == .overlay {
            guard let clipIndex = workingTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) else { continue }
            if workingTracks[trackIndex].clips[clipIndex].transform == transform { return }
            workingTracks[trackIndex].clips[clipIndex].transform = transform
            return
        }
    }

    /// Text payload for the given `MediaClip.id` when the asset is `.text`.
    func textOverlayDescriptor(for clipId: UUID) -> TextOverlayDescriptor? {
        for track in workingTracks {
            guard let clip = track.clips.first(where: { $0.id == clipId }) else { continue }
            if case .text(let d) = clip.asset { return d }
        }
        return nil
    }

    /// Replaces the text clip’s `TextOverlayDescriptor` while keeping id, transform, and time ranges.
    func replaceTextOverlayDescriptor(clipId: UUID, descriptor: TextOverlayDescriptor) {
        for trackIndex in workingTracks.indices {
            guard let clipIndex = workingTracks[trackIndex].clips.firstIndex(where: { $0.id == clipId }) else { continue }
            let old = workingTracks[trackIndex].clips[clipIndex]
            guard case .text = old.asset else { return }
            let updated = MediaClip(
                id: old.id,
                asset: .text(descriptor),
                timelineRange: old.timelineRange,
                sourceRange: old.sourceRange,
                transitionOut: old.transitionOut,
                effects: old.effects,
                transform: old.transform,
                opacity: old.opacity
            )
            workingTracks[trackIndex].clips[clipIndex] = updated
            publishTimelineAndToolbar()
            return
        }
    }

    /// All text clips in timeline order (later entries paint on top when stacked).
    func allTextOverlayClips() -> [(clip: MediaClip, descriptor: TextOverlayDescriptor)] {
        var result: [(MediaClip, TextOverlayDescriptor)] = []
        for track in workingTracks where track.trackType == .overlay {
            for clip in track.clips {
                if case .text(let d) = clip.asset {
                    result.append((clip, d))
                }
            }
        }
        return result
    }

    /// Text overlays as domain items (timeline + `TextOverlayDescriptor` + transform).
    func allTextOverlayItems() -> [TextOverlayItem] {
        allTextOverlayClips().map { TextOverlayItem(clip: $0.clip, descriptor: $0.descriptor) }
    }

    /// Text clips visible at `time` on the project timeline.
    func activeTextOverlays(at time: CMTime) -> [TextOverlayItem] {
        allTextOverlayItems().filter { $0.isActive(at: time) }
    }

    /// Overlay text + stickers in paint order (matches `EditingProject.tracks` overlay lanes).
    func overlayCanvasClipsInPaintOrder() -> [OverlayCanvasClip] {
        var clips: [OverlayCanvasClip] = []
        for track in workingTracks where track.trackType == .overlay {
            for clip in track.clips {
                switch clip.asset {
                case .text(let descriptor):
                    clips.append(
                        OverlayCanvasClip(
                            id: clip.id,
                            timelineRange: clip.timelineRange,
                            transform: clip.transform,
                            opacity: clip.opacity,
                            kind: .text(descriptor)
                        )
                    )
                case .image(let url):
                    clips.append(
                        OverlayCanvasClip(
                            id: clip.id,
                            timelineRange: clip.timelineRange,
                            transform: clip.transform,
                            opacity: clip.opacity,
                            kind: .sticker(url)
                        )
                    )
                default:
                    break
                }
            }
        }
        return clips
    }

    /// Keeps the model playhead in sync for queries that do not receive an explicit `CMTime`.
    func notePlaybackTimelineSeconds(_ seconds: Double) {
        let clamped = max(0, seconds)
        currentPlaybackTimelineSeconds = clamped
    }

    func addAudioFromBrowseItem(_ item: AudioBrowseItem) async {
        guard let url = item.url else {
            print("Audio browse item has no file URL: \(item.id)")
            return
        }
        let asset: AssetIdentifier = .audio(url)
        let duration = await AssetDurationResolver.sourceDuration(for: asset) ?? 5
        await appendClip(to: .audio, asset: asset, duration: duration)
    }

    /// Imports from the photo picker: appends each image/video to the first video (master) track, end-to-end.
    func appendImportedMediaToMasterVideoTrack(_ items: [ProjectFactory.ImportedMedia]) async {
        guard !items.isEmpty else { return }
        let fingerprintBefore = previewCompositionFingerprintNow()
        for item in items {
            switch item.asset.mediaType {
            case .audio:
                continue
            case .image, .text:
                await appendClip(
                    to: .video,
                    asset: item.asset,
                    duration: EditorTimelinePolicy.default.preferredImageDuration,
                    alwaysCreateNewTrack: false,
                    publishChanges: false
                )
            case .video:
                var duration = max(0, item.durationSeconds ?? 0)
                if duration <= 0, case .video(let url) = item.asset {
                    let seconds = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
                    duration = seconds.isFinite && seconds > 0 ? seconds : EditorTimelinePolicy.default.minClipDuration
                }
                await appendClip(
                    to: .video,
                    asset: item.asset,
                    duration: duration,
                    alwaysCreateNewTrack: false,
                    publishChanges: false
                )
            }
        }
        let fingerprintAfter = previewCompositionFingerprintNow()
        if fingerprintBefore != fingerprintAfter {
            previewCompositionGeneration &+= 1
        }
        publishTimelineAndToolbar()
    }

    func handleMainMenuFeatureSelection(_ item: FeatureItem) async {
        switch item.id {
        case "text":
            // Text flow is driven from `EditorViewController.presentTextBottomSheet()`.
            break

        case "sticker":
            guard let url = testMediaLocator.url(resource: "img1", extension: "jpg") else {
                print("Missing bundled test media: img1.jpg")
                return
            }
            await appendClip(to: .overlay, asset: .image(url), duration: 3)

        case "audio":
            // The editor presents the audio sheet from `EditorViewController`; this path is unused from the strip.
            break
        default:
            print("Feature view didSelect item: \(item)")
        }
    }

    // MARK: - Private

    private func formattedProjectEndTime() -> String {
        TimelineClockFormatter.string(fromSeconds: projectSnapshot().totalDuration.seconds)
    }

    private var masterTrackEndSeconds: Double? {
        let videoTracks = workingTracks.filter { $0.trackType == .video }
        guard !videoTracks.isEmpty else { return nil }
        let end = videoTracks
            .flatMap(\.clips)
            .map(\.timelineRange.endSeconds)
            .max() ?? 0
        return end > 0 ? end : nil
    }

    /// By default each inserted test media gets its own dedicated track lane.
    private func appendClip(
        to trackType: MediaTrack.TrackType,
        asset: AssetIdentifier,
        duration: Double,
        alwaysCreateNewTrack: Bool = true,
        publishChanges: Bool = true,
        initialTransform: TransformEffect = .identity
    ) async {
        let fingerprintBefore = publishChanges ? previewCompositionFingerprintNow() : 0
        defer {
            if publishChanges {
                let fingerprintAfter = previewCompositionFingerprintNow()
                if fingerprintBefore != fingerprintAfter {
                    previewCompositionGeneration &+= 1
                }
                publishTimelineAndToolbar()
            }
        }

        let minDuration = EditorTimelinePolicy.default.minClipDuration
        let safeDuration = max(duration, minDuration)
        let timelineDuration: Double
        if trackType == .video {
            timelineDuration = safeDuration
        } else if let masterDuration = masterTrackEndSeconds {
            timelineDuration = min(safeDuration, masterDuration)
        } else {
            timelineDuration = safeDuration
        }
        let sourceDuration = await AssetDurationResolver.sourceDuration(for: asset) ?? safeDuration
        let sourceRange = ClipTimeRange(startSeconds: 0, durationSeconds: sourceDuration)

        let resolvedTransform: TransformEffect = {
            if trackType == .overlay, case .image = asset, initialTransform == .identity {
                return .overlayStickerDefault
            }
            return initialTransform
        }()

        if alwaysCreateNewTrack {
            let range = ClipTimeRange(startSeconds: 0, durationSeconds: timelineDuration)
            let clip = MediaClip(
                asset: asset,
                timelineRange: range,
                sourceRange: sourceRange,
                transform: resolvedTransform
            )
            workingTracks.append(MediaTrack(trackType: trackType, clips: [clip]))
            return
        }

        if let existingIndex = workingTracks.firstIndex(where: { $0.trackType == trackType }) {
            let start = workingTracks[existingIndex].clips.map(\.timelineRange.endSeconds).max() ?? 0
            let range = ClipTimeRange(startSeconds: start, durationSeconds: timelineDuration)
            let clip = MediaClip(
                asset: asset,
                timelineRange: range,
                sourceRange: sourceRange,
                transform: resolvedTransform
            )
            workingTracks[existingIndex].clips.append(clip)
        } else {
            let range = ClipTimeRange(startSeconds: 0, durationSeconds: timelineDuration)
            let clip = MediaClip(
                asset: asset,
                timelineRange: range,
                sourceRange: sourceRange,
                transform: resolvedTransform
            )
            workingTracks.append(MediaTrack(trackType: trackType, clips: [clip]))
        }
    }

    private func publishTimelineAndToolbar() {
        delegate?.editorViewModelDidRequestTimelineReload(self)
        delegate?.editorViewModel(self, didUpdateToolbarTotalDuration: formattedProjectEndTime())
    }

    /// Canvas gestures update `workingTracks` for overlay text and stickers; timeline lanes keep snapshots that
    /// omit those edits until a lane-specific sync. Re-apply `transform` / `opacity` from the model for matching ids.
    private static func mergingAuthoritativeCanvasOverlayVisuals(
        baseline: [MediaTrack],
        timelineTracks: [MediaTrack]
    ) -> [MediaTrack] {
        var visualByClipId: [UUID: (transform: TransformEffect, opacity: Float)] = [:]
        for track in baseline where track.trackType == .overlay {
            for clip in track.clips {
                switch clip.asset {
                case .text, .image:
                    visualByClipId[clip.id] = (clip.transform, clip.opacity)
                default:
                    break
                }
            }
        }
        guard !visualByClipId.isEmpty else { return timelineTracks }

        var merged = timelineTracks
        for trackIndex in merged.indices where merged[trackIndex].trackType == .overlay {
            for clipIndex in merged[trackIndex].clips.indices {
                switch merged[trackIndex].clips[clipIndex].asset {
                case .text, .image:
                    break
                default:
                    continue
                }
                let id = merged[trackIndex].clips[clipIndex].id
                guard let preserved = visualByClipId[id] else { continue }
                merged[trackIndex].clips[clipIndex].transform = preserved.transform
                merged[trackIndex].clips[clipIndex].opacity = preserved.opacity
            }
        }
        return merged
    }

    private func previewCompositionFingerprintNow() -> UInt64 {
        Self.previewCompositionFingerprint(tracks: workingTracks, canvasBackground: workingCanvasBackground)
    }

    /// Fingerprint of everything that affects `PreviewTimelineCompositionBuilder` output.
    /// Skips `.text` on overlay tracks so text stays UIKit-only during editing.
    private static func previewCompositionFingerprint(tracks: [MediaTrack], canvasBackground: CanvasBackgroundSettings) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(canvasBackground.style.rawValue)
        hasher.combine(canvasBackground.primaryHex)
        hasher.combine(canvasBackground.secondaryHex)
        for track in tracks {
            hasher.combine(track.id)
            hasher.combine(track.trackType.rawValue)
            hasher.combine(track.isMuted)
            hasher.combine(track.volume)
            for clip in track.clips {
                if track.trackType == .overlay {
                    switch clip.asset {
                    case .text, .image:
                        continue
                    default:
                        break
                    }
                }
                hasher.combine(clip.id)
                hasher.combine(clip.asset)
                hasher.combine(clip.timelineRange.startSeconds)
                hasher.combine(clip.timelineRange.durationSeconds)
                hasher.combine(clip.sourceRange.startSeconds)
                hasher.combine(clip.sourceRange.durationSeconds)
                hasher.combine(clip.transform.normalizedCenter.x)
                hasher.combine(clip.transform.normalizedCenter.y)
                hasher.combine(clip.transform.normalizedSize.width)
                hasher.combine(clip.transform.normalizedSize.height)
                hasher.combine(clip.transform.rotationAngle)
                hasher.combine(clip.opacity)
                if let transition = clip.transitionOut {
                    hasher.combine(transition.type.rawValue)
                    hasher.combine(transition.durationSeconds)
                } else {
                    hasher.combine(UInt8(0))
                }
                combineEffectsFingerprint(clip.effects, into: &hasher)
            }
        }
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    private static func combineEffectsFingerprint(_ effects: [EffectConfiguration], into hasher: inout Hasher) {
        hasher.combine(effects.count)
        guard !effects.isEmpty, let data = try? JSONEncoder().encode(effects) else { return }
        hasher.combine(data)
    }
}
