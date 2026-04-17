//
// StillVideoEngineTests
// VideoEditorTests
//  Created by Coder ACJHP on 27.03.2026.

//  Validates StillVideoCache → AVAsset and CompositionBuilder → AVPlayerItem.
//  Test host: VideoEditor.app — `Bundle(for: CompositionBuilder.self)` resolves bundled media.
//

import AVFoundation
import XCTest
@testable import VideoEditor

final class StillVideoEngineTests: XCTestCase {

    private var renderSize: CGSize { CGSize(width: 1080, height: 1920) }
    /// Player created inside `waitForPlayerItemReady`; retained so short-lived item loads can finish.
    private var playerLoadProbe: AVPlayer?

    /// Sample image shipped with the app target (Copy Bundle Resources).
    private func bundledSampleImageURL() throws -> URL {
        let bundle = Bundle(for: CompositionBuilder.self)
        let url = bundle.url(forResource: "img2", withExtension: "png")
            ?? bundle.url(forResource: "img1", withExtension: "jpg")
        return try XCTUnwrap(url, "Add img2.png or img1.jpg to the VideoEditor target’s Copy Bundle Resources.")
    }

    // MARK: - StillVideoCache

    func testStillVideoCacheProducesPlayableVideoTrack() async throws {
        let url = try bundledSampleImageURL()
        let asset = try await StillVideoCache.shared.asset(for: url, renderSize: renderSize)

        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(tracks.count, 1, "Cached still MOV must expose exactly one video track.")

        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0.04, "Writer emits two frames ~1/30s each; duration should be positive.")
        XCTAssertLessThan(CMTimeGetSeconds(duration), 0.25)

        let playable = try await asset.load(.isPlayable)
        XCTAssertTrue(playable, "Intermediate still MOV should be directly playable by AVFoundation.")
    }

    /// Smoke-test the intermediate asset alone: `AVPlayerItem` should reach `.readyToPlay`.
    func testDirectPlayerItemFromStillAssetBecomesReady() async throws {
        let url = try bundledSampleImageURL()
        let asset = try await StillVideoCache.shared.asset(for: url, renderSize: renderSize)
        let item = AVPlayerItem(asset: asset)

        let didBecomeReady = await waitForPlayerItemReady(item, timeoutSeconds: 15)
        XCTAssertTrue(didBecomeReady, "Still asset should load in isolation. Error: \(String(describing: item.error))")
    }

    // MARK: - CompositionBuilder (image-only)

    /// With a populated video track, `hasRenderableVideo` is true and `CompositionBuilder` writes video only—
    /// no extra silent audio bed (see `build` branch 3b).
    func testCompositionBuilderImageOnlyProjectInsertsVideoWithoutSeparateAudioBed() async throws {
        let imageURL = try bundledSampleImageURL()
        let clip = MediaClip(
            imageAsset: .image(imageURL),
            timelineOffset: 0,
            duration: 2.5
        )
        let track = MediaTrack(trackType: .video, clips: [clip])
        let project = EditingProject(name: "StillImageTest", tracks: [track])

        let result = try await CompositionBuilder().build(from: project)

        let videoTracks = result.composition.tracks(withMediaType: .video)
        XCTAssertEqual(videoTracks.count, 1)
        let vDuration = try await videoTracks[0].load(.timeRange)
        XCTAssertEqual(CMTimeGetSeconds(vDuration.duration), 2.5, accuracy: 0.08)

        let audioTracks = result.composition.tracks(withMediaType: .audio)
        XCTAssertTrue(audioTracks.isEmpty)

        let compDuration = try await result.composition.load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(compDuration), 2.5, accuracy: 0.08)
    }

    func testFullPreviewPlayerItemBecomesReady() async throws {
        let imageURL = try bundledSampleImageURL()
        let clip = MediaClip(
            imageAsset: .image(imageURL),
            timelineOffset: 0,
            duration: 2.0
        )
        let project = EditingProject(
            name: "StillImagePreviewTest",
            tracks: [MediaTrack(trackType: .video, clips: [clip])]
        )

        let result = try await CompositionBuilder().build(from: project)
        let item = result.playerItem

        let ok = await waitForPlayerItemReady(item, timeoutSeconds: 20)
        XCTAssertTrue(ok, "Full composition + videoComposition should become ready. Error: \(String(describing: item.error))")
    }

    // MARK: - Helpers

    /// Short MOVs often need an attached `AVPlayer` before `AVPlayerItem` finishes loading.
    private func waitForPlayerItemReady(_ item: AVPlayerItem, timeoutSeconds: TimeInterval) async -> Bool {
        await MainActor.run {
            let p = AVPlayer(playerItem: item)
            p.pause()
            playerLoadProbe = p
        }
        defer { playerLoadProbe = nil }
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let status = await MainActor.run { item.status }
            switch status {
            case .readyToPlay:
                return true
            case .failed:
                return false
            default:
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return await MainActor.run { item.status == .readyToPlay }
    }
}
