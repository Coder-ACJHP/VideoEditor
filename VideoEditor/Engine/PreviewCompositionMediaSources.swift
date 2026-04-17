//
// PreviewCompositionMediaSources
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Media sources for `PreviewTimelineVideoClip`: file video, stills (donor + CIImage),
//  and the clip wrapper that applies `insertTimeRange` / `scaleTimeRange` into `AVMutableComposition`.
//

import AVFoundation
import CoreImage
import Foundation

// MARK: - Insert plan (asset track + source range + target duration)

/// One composition insert: which asset track, source window, and scaled duration.
struct AssetTrackInsertionPlan {
    var track: AVAssetTrack
    var selectedTimeRange: CMTimeRange
    var scaleToDuration: CMTime
}

// MARK: - Abstract media source

/// Subclasses describe real video tracks or placeholder tracks.
class PreviewCompositionMediaSource: NSObject {

    var duration: CMTime = .zero
    var selectedTimeRange: CMTimeRange = .zero
    private var scaledDurationStorage: CMTime = .invalid

    var scaledDuration: CMTime {
        get { scaledDurationStorage.isValid ? scaledDurationStorage : selectedTimeRange.duration }
        set { scaledDurationStorage = newValue }
    }

    /// Fallback bundle asset when a subclass does not override `tracks(for:)`.
    private static var sharedEmptyAsset: AVURLAsset? = {
        guard let url = Bundle.main.url(forResource: "black_empty", withExtension: "mp4") else { return nil }
        return AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    }()

    func tracks(for type: AVMediaType) async -> [AVAssetTrack] {
        guard let asset = Self.sharedEmptyAsset else { return [] }
        return (try? await asset.loadTracks(withMediaType: type)) ?? []
    }

    func trackInfo(for type: AVMediaType, at index: Int) async -> AssetTrackInsertionPlan {
        let track = await tracks(for: type)[index]
        let nominal = CMTime(value: 1, timescale: 30)
        let emptySlice = CMTimeRange(start: .zero, duration: nominal)
        return AssetTrackInsertionPlan(track: track, selectedTimeRange: emptySlice, scaleToDuration: scaledDuration)
    }

    func image(at time: CMTime, renderSize: CGSize) -> CIImage? { nil }
}

// MARK: - Still image (donor segment + time stretch)

final class StillImagePreviewMediaSource: PreviewCompositionMediaSource {

    private let ciImageStored: CIImage
    private let donorTrack: AVAssetTrack
    private let donorSourceSlice: CMTimeRange

    init(ciImage: CIImage, scaledDuration: CMTime, donorTrack: AVAssetTrack, donorSourceSlice: CMTimeRange) {
        self.ciImageStored = ciImage
        self.donorTrack = donorTrack
        self.donorSourceSlice = donorSourceSlice
        super.init()
        self.duration = scaledDuration
        selectedTimeRange = CMTimeRange(start: .zero, duration: scaledDuration)
        self.scaledDuration = scaledDuration
    }

    override func tracks(for type: AVMediaType) async -> [AVAssetTrack] {
        guard type == .video else { return [] }
        return [donorTrack]
    }

    override func trackInfo(for type: AVMediaType, at index: Int) async -> AssetTrackInsertionPlan {
        AssetTrackInsertionPlan(
            track: donorTrack,
            selectedTimeRange: donorSourceSlice,
            scaleToDuration: scaledDuration
        )
    }

    override func image(at time: CMTime, renderSize: CGSize) -> CIImage? {
        ciImageStored
    }
}

// MARK: - File-backed video

final class FileVideoPreviewMediaSource: PreviewCompositionMediaSource {

    let urlAsset: AVURLAsset
    private(set) var cachedVideoTracks: [AVAssetTrack] = []

    init(urlAsset: AVURLAsset, selectedTimeRange: CMTimeRange, scaledDuration: CMTime) {
        self.urlAsset = urlAsset
        super.init()
        self.selectedTimeRange = selectedTimeRange
        self.scaledDuration = scaledDuration
        self.duration = scaledDuration
    }

    func setVideoTracks(_ tracks: [AVAssetTrack]) {
        cachedVideoTracks = tracks
    }

    override func tracks(for type: AVMediaType) async -> [AVAssetTrack] {
        guard type == .video else { return [] }
        return cachedVideoTracks
    }

    override func trackInfo(for type: AVMediaType, at index: Int) async -> AssetTrackInsertionPlan {
        let track = cachedVideoTracks[index]
        return AssetTrackInsertionPlan(
            track: track,
            selectedTimeRange: selectedTimeRange,
            scaleToDuration: scaledDuration
        )
    }
}

// MARK: - Timeline clip → composition track

final class PreviewTimelineVideoClip: NSObject, PreviewCompositionVideoSource {

    let mediaSource: PreviewCompositionMediaSource
    var startTime: CMTime = .zero
    var visualStyle = PreviewClipVisualStyle()
    var transitionOut: ClipTransition?

    var duration: CMTime { mediaSource.scaledDuration }

    init(mediaSource: PreviewCompositionMediaSource) {
        self.mediaSource = mediaSource
        super.init()
    }

    func numberOfVideoTracks() async -> Int {
        await mediaSource.tracks(for: .video).count
    }

    @MainActor
    func videoCompositionTrack(
        for composition: AVMutableComposition,
        at index: Int,
        preferredTrackID: Int32
    ) async -> AVCompositionTrack? {
        guard await index < numberOfVideoTracks() else { return nil }
        let plan = await mediaSource.trackInfo(for: .video, at: index)
        let srcTrack = plan.track

        let preferredTransform: CGAffineTransform
        do {
            preferredTransform = try await srcTrack.load(.preferredTransform)
        } catch {
            assertionFailure("Preview composition: preferredTransform load failed: \(error)")
            return nil
        }
        let mediaType = srcTrack.mediaType

        let compositionTrack: AVMutableCompositionTrack
        if let existing = composition.track(withTrackID: preferredTrackID) {
            compositionTrack = existing
        } else if let created = composition.addMutableTrack(
            withMediaType: mediaType,
            preferredTrackID: preferredTrackID
        ) {
            compositionTrack = created
        } else {
            return nil
        }

        compositionTrack.setStoredPreferredTransform(preferredTransform, forKey: timeRange.transformStorageKey)

        let removeRange = CMTimeRange(start: timeRange.start, duration: plan.scaleToDuration)
        compositionTrack.removeTimeRange(removeRange)
        do {
            try compositionTrack.insertTimeRange(plan.selectedTimeRange, of: plan.track, at: timeRange.start)
            compositionTrack.scaleTimeRange(
                CMTimeRange(start: timeRange.start, duration: plan.selectedTimeRange.duration),
                toDuration: plan.scaleToDuration
            )
        } catch {
            assertionFailure("Preview composition insert failed: \(error)")
        }
        return compositionTrack
    }

    func applyEffect(to sourceImage: CIImage, at time: CMTime, renderSize: CGSize) -> CIImage {
        let relative = CMTimeSubtract(time, startTime)
        let base = mediaSource.image(at: relative, renderSize: renderSize) ?? sourceImage
        let context = PreviewFrameEffectContext(time: time, renderSize: renderSize, timeRange: timeRange)
        return visualStyle.applyEffect(to: base, info: context)
    }
}
