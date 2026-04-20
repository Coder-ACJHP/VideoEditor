//
// PreviewTimelineCompositionBuilder
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  `EditingProject` → `AVPlayerItem` + custom `AVVideoComposition`.
//  Each clip maps to its own composition video track; stills use a donor segment + `scaleTimeRange` to stretch duration.
//

import AVFoundation
import CoreGraphics
import CoreImage
import ImageIO
import UIKit

final class PreviewTimelineCompositionBuilder: CompositionBuilding {

    private var assetCache: [URL: AVURLAsset] = [:]
    private var blackEmptyAssetRetain: AVURLAsset?
    private let renderSize = CGSize(width: 1080, height: 1920)

    func build(from project: EditingProject, options: CompositionBuildOptions) async throws -> CompositionBuildResult {
        assetCache.removeAll()
        blackEmptyAssetRetain = nil

        let timescale = CMTimeScale(600)
        let allEnds = project.tracks.flatMap(\.clips).map { $0.timelineRange.cmTimeRange.end }
        let maxEnd = allEnds.max() ?? .zero
        let projectDur = CMTimeMaximum(
            CMTimeConvertScale(project.totalDuration, timescale: timescale, method: .roundAwayFromZero),
            CMTimeConvertScale(maxEnd, timescale: timescale, method: .roundAwayFromZero)
        )

        let needsStillDonor = project.tracks.contains { lane in
            guard lane.trackType != .audio else { return false }
            return lane.clips.contains { $0.asset.mediaType == .image }
        }

        let donor: (AVURLAsset, AVAssetTrack, CMTimeRange)?
        if needsStillDonor {
            let d = try await PreviewCompositionAssembler.loadBlackEmptyDonor()
            blackEmptyAssetRetain = d.asset
            donor = d
        } else {
            donor = nil
        }

        var mainChannel: [PreviewCompositionVideoSource] = []
        var overlayChannel: [PreviewCompositionVideoSource] = []

        for track in project.tracks {
            switch track.trackType {
                case .video:
                    let vClips = track.clips
                    for (idx, clip) in vClips.enumerated() {
                        let leadIn = Self.compositionLeadIn(forClipAt: idx, in: vClips)
                        if let item = try await makePreviewClip(from: clip, compositionLeadIn: leadIn, donor: donor) {
                            mainChannel.append(item)
                        }
                    }
                case .overlay:
                    let oClips = track.clips
                    for (idx, clip) in oClips.enumerated() {
                        let leadIn = Self.compositionLeadIn(forClipAt: idx, in: oClips)
                        // Text uses `PreviewTextOverlaySpec` when `options.includeTextOverlaysInVideoComposition` is set.
                        if case .text = clip.asset { continue }
                        if !options.includeRasterStickerOverlaysInVideoComposition, case .image = clip.asset {
                            continue
                        }
                        if let item = try await makePreviewClip(from: clip, compositionLeadIn: leadIn, donor: donor) {
                            overlayChannel.append(item)
                        }
                    }
                case .audio:
                    break
            }
        }

        let textOverlaySpecs = Self.makeTextOverlaySpecs(from: project, includeText: options.includeTextOverlaysInVideoComposition)

        let (composition, videoComposition) = try await PreviewCompositionAssembler.build(
            renderSize: renderSize,
            projectDuration: projectDur,
            videoChannel: mainChannel,
            overlays: overlayChannel,
            textOverlays: textOverlaySpecs,
            canvasBackgroundSettings: project.canvasBackground
        )

        try await insertAudioTracks(from: project, into: composition, projectDuration: projectDur)

        for media in [AVMediaType.video, AVMediaType.audio] {
            for compTrack in composition.tracks(withMediaType: media) {
                let trackEnd = compTrack.timeRange.end
                if CMTimeCompare(projectDur, trackEnd) > 0 {
                    let gap = CMTimeSubtract(projectDur, trackEnd)
                    if gap.seconds > 0 {
                        compTrack.insertEmptyTimeRange(CMTimeRange(start: trackEnd, duration: gap))
                    }
                }
            }
        }

        let videoTracks = composition.tracks(withMediaType: .video)
        let playerItem = AVPlayerItem(asset: composition)
        if !videoTracks.isEmpty {
            playerItem.videoComposition = videoComposition
            playerItem.seekingWaitsForVideoCompositionRendering = true
        }

        let audioTracks = composition.tracks(withMediaType: .audio)
        let audioMix: AVAudioMix?
        if !audioTracks.isEmpty {
            let mix = AVMutableAudioMix()
            mix.inputParameters = audioTracks.map { t in
                let parameters = AVMutableAudioMixInputParameters(track: t)
                parameters.setVolumeRamp(
                    fromStartVolume: 1,
                    toEndVolume: 1,
                    timeRange: CMTimeRange(
                        start: .zero,
                        duration: composition.duration
                    )
                )
                return parameters
            }
            playerItem.audioMix = mix
            audioMix = mix
        } else {
            audioMix = nil
        }

        return CompositionBuildResult(
            playerItem: playerItem,
            composition: composition,
            videoComposition: videoComposition,
            overlayLayers: [],
            audioMix: audioMix
        )
    }

    private static func makeTextOverlaySpecs(from project: EditingProject, includeText: Bool) -> [PreviewTextOverlaySpec] {
        guard includeText else { return [] }
        var specs: [PreviewTextOverlaySpec] = []
        for track in project.tracks where track.trackType == .overlay {
            for clip in track.clips {
                guard case .text(let descriptor) = clip.asset else { continue }
                specs.append(
                    PreviewTextOverlaySpec(
                        visibleTimeRange: clip.timelineRange.cmTimeRange,
                        descriptor: descriptor,
                        transform: clip.transform,
                        opacity: clip.opacity
                    )
                )
            }
        }
        return specs
    }

    // MARK: - Clip → preview source

    // Downsample core image to avoid memory consuming
    private func downsampleCIImage(from url: URL) -> CIImage? {
        // 1. Load the image and apply orientation
        let options: [CIImageOption: Any] = [.applyOrientationProperty: true]
        guard var ci = CIImage(contentsOf: url, options: options) else { return nil }

        // 2. Smart resize (Downsampling)
        let imageSize = ci.extent.size

        // If any dimention of image is grater than render size start process
        if imageSize.width > renderSize.width || imageSize.height > renderSize.height {

            let widthRatio = renderSize.width / imageSize.width
            let heightRatio = renderSize.height / imageSize.height
            let scale = max(widthRatio, heightRatio)

            // Downsample only (do not dissort by scaling up)
            if scale < 1.0 {
                let transform = CGAffineTransform(scaleX: scale, y: scale)
                ci = ci.transformed(by: transform)
            }
        }
        return ci
    }

    /// If the previous clip has `transitionOut`, this clip starts earlier in the composition by `leadIn` while the timeline model stays end-to-end.
    private static func compositionLeadIn(forClipAt index: Int, in clips: [MediaClip]) -> CMTime {
        guard index > 0 else { return .zero }
        let previous = clips[index - 1]
        guard let transition = previous.transitionOut else { return .zero }
        let overlap = transition.resolvedOverlapSeconds(
            outgoingTimelineDuration: previous.timelineRange.durationSeconds,
            incomingTimelineDuration: clips[index].timelineRange.durationSeconds
        )
        guard overlap > 0 else { return .zero }
        return CMTime(seconds: overlap, preferredTimescale: 600)
    }

    private func makePreviewClip(
        from clip: MediaClip,
        compositionLeadIn: CMTime,
        donor: (AVURLAsset, AVAssetTrack, CMTimeRange)?
    ) async throws -> PreviewTimelineVideoClip? {
        let timeline = clip.timelineRange.cmTimeRange
        let compositionStart = CMTimeSubtract(timeline.start, compositionLeadIn)
        let wallDuration = CMTimeAdd(timeline.duration, compositionLeadIn)

        switch clip.asset {
            case .image(let url):

                guard let donor, let downsampled = downsampleCIImage(from: url) else { return nil }

                let source = StillImagePreviewMediaSource(
                    ciImage: downsampled,
                    scaledDuration: wallDuration,
                    donorTrack: donor.1,
                    donorSourceSlice: donor.2
                )

                let item = PreviewTimelineVideoClip(mediaSource: source)
                item.startTime = compositionStart
                item.visualStyle.opacity = clip.opacity
                item.transitionOut = clip.transitionOut
                return item

            case .video(let url):
                let asset = cachedAsset(for: url)
                let vTracks = try await asset.loadTracks(withMediaType: .video)
                guard let v0 = vTracks.first else { return nil }
                let assetDur = try await asset.load(.duration)
                let src = clip.sourceRange.cmTimeRange
                let s0 = CMTimeMaximum(.zero, src.start)
                let s1 = CMTimeMinimum(assetDur, CMTimeAdd(src.start, src.duration))
                guard CMTimeCompare(s1, s0) > 0 else { return nil }
                let selected = CMTimeRange(start: s0, duration: CMTimeSubtract(s1, s0))
                let fileSource = FileVideoPreviewMediaSource(
                    urlAsset: asset,
                    selectedTimeRange: selected,
                    scaledDuration: wallDuration
                )
                fileSource.setVideoTracks([v0])
                let item = PreviewTimelineVideoClip(mediaSource: fileSource)
                item.startTime = compositionStart
                item.visualStyle.opacity = clip.opacity
                item.transitionOut = clip.transitionOut
                return item

            case .phAssetVideo, .phAssetImage, .text, .audio:
                return nil
        }
    }

    // MARK: - Audio tracks

    private func insertAudioTracks(
        from project: EditingProject,
        into composition: AVMutableComposition,
        projectDuration: CMTime
    ) async throws {
        for track in project.tracks where track.trackType == .audio {
            let hasAudio = track.clips.contains { $0.asset.mediaType == .audio }
            guard hasAudio else { continue }
            guard let compTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            for clip in track.clips {
                guard case .audio(let url) = clip.asset else { continue }
                let asset = cachedAsset(for: url)
                let aTracks = try await asset.loadTracks(withMediaType: .audio)
                guard let a0 = aTracks.first else { continue }
                let assetDur = try await asset.load(.duration)
                let src = clip.sourceRange.cmTimeRange
                let s0 = CMTimeMaximum(.zero, src.start)
                let s1 = CMTimeMinimum(assetDur, CMTimeAdd(src.start, src.duration))
                guard CMTimeCompare(s1, s0) > 0 else { continue }
                let selected = CMTimeRange(start: s0, duration: CMTimeSubtract(s1, s0))
                try compTrack.insertTimeRange(selected, of: a0, at: clip.timelineRange.cmTimeRange.start)
            }

            let trackEnd = compTrack.timeRange.end
            if CMTimeCompare(projectDuration, trackEnd) > 0 {
                let gap = CMTimeSubtract(projectDuration, trackEnd)
                if gap.seconds > 0 {
                    compTrack.insertEmptyTimeRange(CMTimeRange(start: trackEnd, duration: gap))
                }
            }
        }
    }

    private func cachedAsset(for url: URL) -> AVURLAsset {
        if let existing = assetCache[url] { return existing }
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        assetCache[url] = asset
        return asset
    }
}

typealias CompositionBuilder = PreviewTimelineCompositionBuilder
