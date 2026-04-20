//
// PreviewVideoCompositionCore
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Custom `AVVideoCompositing` (Core Image) implementation, `AVVideoCompositionInstruction`
//  application, and `AVMutableComposition` + `AVMutableVideoComposition` setup (`PreviewCompositionAssembler`).
//

import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import Foundation

// MARK: - Layer task

final class PreviewVideoLayerInstruction {

    let trackID: Int32
    var timeRange: CMTimeRange = .zero
    var transitionOut: ClipTransition?
    var preferredTransform: CGAffineTransform?
    var frameEffectSource: PreviewCompositionVideoSource?

    init(trackID: Int32, source: PreviewCompositionVideoSource) {
        self.trackID = trackID
        self.frameEffectSource = source
    }

    func apply(sourceImage: CIImage, at time: CMTime, renderSize: CGSize) -> CIImage {
        var image = sourceImage
        if let t = preferredTransform {
            image = image.applyingPreviewPreferredTransform(t)
        }
        guard let source = frameEffectSource else { return image }
        return source.applyEffect(to: image, at: time, renderSize: renderSize)
    }
}

// MARK: - Combined instruction (multi-track)

final class PreviewMultiTrackVideoInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {

    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening: Bool
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID

    var layerInstructions: [PreviewVideoLayerInstruction] = []
    var mainTrackIDs: [Int32] = []
    var passingThroughEffect: PreviewVideoFrameEffect?
    var backgroundColor = CIColor(red: 0, green: 0, blue: 0)
    /// When set, used as the base frame instead of `backgroundColor` (solid or gradient bake).
    var backgroundFillImage: CIImage?
    /// Drawn in the custom compositor after video layers; gated by `visibleTimeRange` per spec.
    var textOverlays: [PreviewTextOverlaySpec] = []

    init(sourceTrackIDs: [Int32], timeRange: CMTimeRange) {
        self.timeRange = timeRange
        self.requiredSourceTrackIDs = sourceTrackIDs.map { NSNumber(value: $0) }
        self.passthroughTrackID = kCMPersistentTrackID_Invalid
        self.containsTweening = true
    }

    func apply(request: AVAsynchronousVideoCompositionRequest) -> CIImage? {
        let time = request.compositionTime
        let renderSize = request.renderContext.size

        var mainLayers: [PreviewVideoLayerInstruction] = []
        var otherLayers: [PreviewVideoLayerInstruction] = []
        for li in layerInstructions {
            if mainTrackIDs.contains(li.trackID) {
                mainLayers.append(li)
            } else {
                otherLayers.append(li)
            }
        }

        var image: CIImage?

        if mainLayers.count == 2,
           mainLayers[0].frameEffectSource != nil,
           mainLayers[1].frameEffectSource != nil {
            let first: PreviewVideoLayerInstruction
            let second: PreviewVideoLayerInstruction
            if CMTimeCompare(mainLayers[0].timeRange.end, mainLayers[1].timeRange.end) < 0 {
                first = mainLayers[0]
                second = mainLayers[1]
            } else {
                first = mainLayers[1]
                second = mainLayers[0]
            }

            if let pb1 = request.sourceFrame(byTrackID: first.trackID),
               let pb2 = request.sourceFrame(byTrackID: second.trackID) {
                let img1 = makeCIImageCorrectingPixelBufferAspectRatio(from: pb1)
                let s1 = first.apply(sourceImage: img1, at: time, renderSize: renderSize)
                if let transition = first.transitionOut {
                    let img2 = makeCIImageCorrectingPixelBufferAspectRatio(from: pb2)
                    let s2 = second.apply(sourceImage: img2, at: time, renderSize: renderSize)
                    let trRange = first.timeRange.intersection(second.timeRange)
                    let tween = transitionTweenProgress(time: time, range: trRange)
                    image = transition.renderImage(
                        foregroundImage: s2,
                        backgroundImage: s1,
                        forTweenFactor: tween,
                        renderSize: renderSize
                    )
                } else {
                    image = s1
                }
            }
        } else {
            for li in mainLayers {
                guard let pb = request.sourceFrame(byTrackID: li.trackID) else { continue }
                let src = makeCIImageCorrectingPixelBufferAspectRatio(from: pb)
                let out = li.apply(sourceImage: src, at: time, renderSize: renderSize)
                if let prev = image {
                    image = out.composited(over: prev)
                } else {
                    image = out
                }
            }
        }

        for li in otherLayers {
            guard let pb = request.sourceFrame(byTrackID: li.trackID) else { continue }
            let src = makeCIImageCorrectingPixelBufferAspectRatio(from: pb)
            let out = li.apply(sourceImage: src, at: time, renderSize: renderSize)
            if let prev = image {
                image = out.composited(over: prev)
            } else {
                image = out
            }
        }

        if let pass = passingThroughEffect, let base = image {
            image = pass.applyEffect(to: base, at: time, renderSize: renderSize)
        }

        image = PreviewTextOverlayCompositor.composite(
            specs: textOverlays,
            onto: image,
            at: time,
            renderSize: renderSize
        )
        return image
    }

    private func transitionTweenProgress(time: CMTime, range: CMTimeRange) -> Float64 {
        let elapsed = CMTimeSubtract(time, range.start)
        let d = CMTimeGetSeconds(range.duration)
        guard d > 0 else { return 0 }
        return CMTimeGetSeconds(elapsed) / d
    }

    private func makeCIImageCorrectingPixelBufferAspectRatio(from pixelBuffer: CVPixelBuffer) -> CIImage {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let attr = CVBufferCopyAttachments(pixelBuffer, .shouldPropagate) as? [String: Any]
        if let aspect = attr?[kCVImageBufferPixelAspectRatioKey as String] as? [String: Any],
           let wNum = aspect[kCVImageBufferPixelAspectRatioHorizontalSpacingKey as String] as? NSNumber,
           let hNum = aspect[kCVImageBufferPixelAspectRatioVerticalSpacingKey as String] as? NSNumber {
            let w = CGFloat(truncating: wNum)
            let h = CGFloat(truncating: hNum)
            if h != 0, w != 0 {
                image = image.transformed(by: CGAffineTransform(scaleX: w / h, y: 1))
            }
        }
        return image
    }
}

// MARK: - Core Image based compositor

final class PreviewCoreImageVideoCompositor: NSObject, AVVideoCompositing {

    static let sRGBSpace = CGColorSpace(name: CGColorSpace.sRGB)
    static var ciContext = CIContext(options: [
        .cacheIntermediates: false,
        .name: "PreviewCompositorContext" // Facilitates profiling in Instruments
    ])

    private let renderContextQueue = DispatchQueue(
        label: "videoeditor.preview.compositor.rendercontext"
    )
    private let renderingQueue = DispatchQueue(
        label: "videoeditor.preview.compositor.rendering",
        attributes: .concurrent
    )
    private var shouldCancelAllRequests = false
    private var latestRenderContext: AVVideoCompositionRenderContext?

    var sourcePixelBufferAttributes: [String: Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        kCVPixelBufferMetalCompatibilityKey as String: true
    ]

    var requiredPixelBufferAttributesForRenderContext: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true
    ]

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContextQueue.sync { latestRenderContext = newRenderContext }
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        renderingQueue.async { [weak self] in
            guard let self else { return }
            if self.shouldCancelAllRequests {
                request.finishCancelledRequest()
                return
            }

            autoreleasepool {
                if let pixelBuffer = self.newRenderedPixelBuffer(for: request) {
                    request.finish(withComposedVideoFrame: pixelBuffer)
                } else {
                    request.finish(with: NSError(domain: "PreviewVideoCompositor", code: -1))
                }
            }
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        shouldCancelAllRequests = true
        renderingQueue.async(flags: .barrier) { [weak self] in
            self?.shouldCancelAllRequests = false
        }
    }

    /// Main rendering logic that combines layers into a single pixel buffer.
    private func newRenderedPixelBuffer(for request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {
        // 1. Obtain a clean pixel buffer from the render context pool
        guard let output = request.renderContext.newPixelBuffer() else { return nil }

        // Ensure the instruction is our custom type to access background color and layer logic
        guard let instruction = request.videoCompositionInstruction as? PreviewMultiTrackVideoInstruction else {
            return nil
        }

        // 2. Initialize the background layer covering the entire render area
        let renderRect = CGRect(origin: .zero, size: request.renderContext.size)
        var image: CIImage
        if let fill = instruction.backgroundFillImage {
            image = fill.cropped(to: renderRect)
        } else {
            image = CIImage(color: instruction.backgroundColor).cropped(to: renderRect)
        }

        // 3. Apply the track composition logic
        if let composed = instruction.apply(request: request) {
            // Optimization: While 'composed' might cover the full frame,
            // compositing over the background ensures no transparency leaks.
            image = composed.composited(over: image)
        }

        // 4. Render the final CIImage into the output pixel buffer
        // Using sRGB color space ensures consistent color reproduction across different display types.
        Self.ciContext.render(image,
                              to: output,
                              bounds: renderRect,
                              colorSpace: Self.sRGBSpace)

        return output
    }
}

// MARK: - Composition factory

enum PreviewCompositionAssemblerError: Error {
    case missingBlackEmptyVideo
    case blackEmptyHasNoVideoTrack
}

enum PreviewCompositionAssembler {

    private final class MainTrackGroup {
        let track: AVCompositionTrack
        var sources: [PreviewCompositionVideoSource]
        init(track: AVCompositionTrack, sources: [PreviewCompositionVideoSource]) {
            self.track = track
            self.sources = sources
        }
    }

    private final class OverlayTrackBinding {
        let track: AVCompositionTrack
        let source: PreviewCompositionVideoSource
        init(track: AVCompositionTrack, source: PreviewCompositionVideoSource) {
            self.track = track
            self.source = source
        }
    }

    /// Provides a donor asset for still image segments with at least one decodable sample duration.
    static func loadBlackEmptyDonor() async throws -> (asset: AVURLAsset, track: AVAssetTrack, sourceSlice: CMTimeRange) {
        guard let url = Bundle.main.url(forResource: "black_empty", withExtension: "mp4") else {
            throw PreviewCompositionAssemblerError.missingBlackEmptyVideo
        }
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw PreviewCompositionAssemblerError.blackEmptyHasNoVideoTrack }
        let trackRange = try await track.load(.timeRange)
        let naturalScale = try await track.load(.naturalTimeScale)
        let fps = try await track.load(.nominalFrameRate)
        let oneSample: CMTime
        if fps > 0.5 {
            oneSample = CMTime(seconds: 1.0 / Double(fps), preferredTimescale: naturalScale)
        } else {
            oneSample = CMTime(value: 1, timescale: naturalScale)
        }
        let oneTick = CMTime(value: 1, timescale: naturalScale)
        var slice = CMTimeMaximum(oneSample, oneTick)
        slice = CMTimeMinimum(slice, trackRange.duration)
        let sliceRange = CMTimeRange(start: trackRange.start, duration: slice)
        return (asset, track, sliceRange)
    }

    /// Main logic: `PreviewTimelineVideoClip` and `AVMutableComposition` should remain on the main actor.
    @MainActor
    static func build(
        renderSize: CGSize,
        projectDuration: CMTime,
        videoChannel: [PreviewCompositionVideoSource],
        overlays: [PreviewCompositionVideoSource],
        textOverlays: [PreviewTextOverlaySpec],
        canvasBackgroundSettings: CanvasBackgroundSettings
    ) async throws -> (composition: AVMutableComposition, videoComposition: AVMutableVideoComposition) {

        let composition = AVMutableComposition(urlAssetInitializationOptions: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])

        var nextTrackID: Int32 = 0
        func generateNextTrackID() -> Int32 {
            nextTrackID += 1
            return nextTrackID
        }

        var videoChannelTrackIDs: [Int: Int32] = [:]
        func videoTrackID(for index: Int) -> Int32 {
            if let existing = videoChannelTrackIDs[index] { return existing }
            let id = generateNextTrackID()
            videoChannelTrackIDs[index] = id
            return id
        }

        var mainTrackGroups: [MainTrackGroup] = []

        for (offset, provider) in videoChannel.enumerated() {
            guard let clip = provider as? PreviewTimelineVideoClip else { continue }
            let trackCount = await clip.numberOfVideoTracks()
            for index in 0..<trackCount {
                let baseID = videoTrackID(for: index)
                let preferredID = baseID + Int32((offset % 2 + 1) * 1_000)
                if let compTrack = await clip.videoCompositionTrack(for: composition, at: index, preferredTrackID: preferredID) {
                    if let existing = mainTrackGroups.first(where: { $0.track === compTrack }) {
                        existing.sources.append(provider)
                    } else {
                        mainTrackGroups.append(MainTrackGroup(track: compTrack, sources: [provider]))
                    }
                }
            }
        }

        var overlayTrackIDs: [Int32] = []
        var overlayBindings: [OverlayTrackBinding] = []

        for provider in overlays {
            guard let clip = provider as? PreviewTimelineVideoClip else { continue }
            let overlayTrackCount = await clip.numberOfVideoTracks()
            for index in 0..<overlayTrackCount {
                let trackID: Int32 = {
                    if let reused = overlayTrackIDs.first(where: { tid -> Bool in
                        guard let t = composition.track(withTrackID: tid) else { return false }
                        for seg in t.segments {
                            if seg.timeMapping.target.start > clip.timeRange.end { break }
                            if seg.timeMapping.target.end < clip.timeRange.start { continue }
                            if !seg.isEmpty {
                                let inter = clip.timeRange.intersection(seg.timeMapping.target)
                                if inter.duration.seconds > 0 { return false }
                            }
                        }
                        return true
                    }) {
                        return reused
                    }
                    return generateNextTrackID()
                }()

                if let compTrack = await clip.videoCompositionTrack(for: composition, at: index, preferredTrackID: trackID) {
                    overlayBindings.append(OverlayTrackBinding(track: compTrack, source: provider))
                }
                if !overlayTrackIDs.contains(trackID) {
                    overlayTrackIDs.append(trackID)
                }
            }
        }

        var layerInstructions: [PreviewVideoLayerInstruction] = []

        for group in mainTrackGroups {
            for provider in group.sources {
                guard let clip = provider as? PreviewTimelineVideoClip else { continue }
                let li = PreviewVideoLayerInstruction(trackID: group.track.trackID, source: clip)
                li.preferredTransform = group.track.storedPreferredTransform(forKey: clip.timeRange.transformStorageKey)
                li.timeRange = clip.timeRange
                li.transitionOut = clip.transitionOut
                layerInstructions.append(li)
            }
        }

        for binding in overlayBindings {
            guard let clip = binding.source as? PreviewTimelineVideoClip else { continue }
            let li = PreviewVideoLayerInstruction(trackID: binding.track.trackID, source: clip)
            li.preferredTransform = binding.track.storedPreferredTransform(forKey: clip.timeRange.transformStorageKey)
            li.timeRange = clip.timeRange
            layerInstructions.append(li)
        }

        layerInstructions.sort { CMTimeCompare($0.timeRange.start, $1.timeRange.start) < 0 }

        let slices = calculateSlices(for: layerInstructions)
        let mainIDs = mainTrackGroups.map(\.track.trackID)
        let instructions: [PreviewMultiTrackVideoInstruction] = slices.map { slice in
            let ids = slice.layers.map(\.trackID)
            let instr = PreviewMultiTrackVideoInstruction(sourceTrackIDs: ids, timeRange: slice.range)
            instr.layerInstructions = slice.layers
            instr.mainTrackIDs = mainIDs.filter { ids.contains($0) }
            return instr
        }

        let backgroundImage = PreviewCompositionCanvasBackground.ciImage(
            renderSize: renderSize,
            settings: canvasBackgroundSettings
        )
        for instr in instructions {
            instr.backgroundFillImage = backgroundImage
            instr.backgroundColor = PreviewCompositionCanvasBackground.ciColor(
                canvasBackgroundColorHex: canvasBackgroundSettings.style == .solid
                    ? canvasBackgroundSettings.primaryHex
                    : nil
            )
            instr.textOverlays = textOverlays.filter { spec in
                instr.timeRange.intersection(spec.visibleTimeRange).duration.seconds > 1e-9
            }
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = renderSize
        videoComposition.instructions = instructions
        videoComposition.customVideoCompositorClass = PreviewCoreImageVideoCompositor.self
        videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid

        return (composition, videoComposition)
    }

    private struct LayerTimeSlice {
        let range: CMTimeRange
        let layers: [PreviewVideoLayerInstruction]
    }

    /// Segments overlapping layer time ranges into discrete, non-overlapping slices.
    private static func calculateSlices(
        for layerInstructions: [PreviewVideoLayerInstruction]
    ) -> [LayerTimeSlice] {
        var slices: [LayerTimeSlice] = []

        for li in layerInstructions {
            var working = slices
            var leftRanges = [li.timeRange]
            var increase = 0

            for (offset, slice) in slices.enumerated() {
                let intersection = slice.range.intersection(li.timeRange)
                guard intersection.duration.seconds > 0 else { continue }

                working.remove(at: offset + increase)

                var newSlices: [LayerTimeSlice] = []
                let pieceRanges = CMTimeRange.splitPairForOverlappingInstructions(li.timeRange, slice.range)
                for tr in pieceRanges {
                    if slice.range.containsTimeRangeFully(tr) {
                        if li.timeRange.containsTimeRangeFully(tr) {
                            newSlices.append(LayerTimeSlice(range: tr, layers: slice.layers + [li]))
                            leftRanges = leftRanges.flatMap { $0.rangesAfterRemoving(tr) }
                        } else {
                            newSlices.append(LayerTimeSlice(range: tr, layers: slice.layers))
                        }
                    }
                }

                for s in newSlices.reversed() {
                    working.insert(s, at: offset + increase)
                }
                increase += newSlices.count - 1
            }

            for tr in leftRanges {
                working.append(LayerTimeSlice(range: tr, layers: [li]))
            }
            slices = working
        }

        return slices.sorted { CMTimeCompare($0.range.start, $1.range.start) < 0 }
    }
}
