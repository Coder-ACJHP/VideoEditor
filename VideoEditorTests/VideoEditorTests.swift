//
//  VideoEditorTests.swift
//  VideoEditorTests
//
//  Created by Coder ACJHP on 17.04.2026.
//  Copyright © 2026 Coder ACJHP. All rights reserved.
//

import AVFoundation
import XCTest
@testable import VideoEditor

final class VideoEditorTests: XCTestCase {

    private func bundledSampleImageURL() throws -> URL {
        let bundles = [Bundle(for: CompositionBuilder.self), Bundle.main]
        let url = bundles.lazy.compactMap { bundle in
            bundle.url(forResource: "img2", withExtension: "png")
                ?? bundle.url(forResource: "img1", withExtension: "jpg")
        }.first
        return try XCTUnwrap(
            url,
            "Add img2.png or img1.jpg to the VideoEditor target’s Copy Bundle Resources."
        )
    }

    @MainActor
    func testSyncTracksFromTimelinePreservesCanvasTextTransformWhenAudioLaneCommits() throws {
        let textClipId = UUID()
        let textDescriptor = TextOverlayDescriptor.defaultNew(text: "Hello")
        let videoURL = URL(fileURLWithPath: "/tmp/sync-test-video.mov")
        let audioURL = URL(fileURLWithPath: "/tmp/sync-test-audio.m4a")

        let videoClip = MediaClip(
            asset: .video(videoURL),
            timelineRange: ClipTimeRange(startSeconds: 0, durationSeconds: 10),
            sourceRange: ClipTimeRange(startSeconds: 0, durationSeconds: 10)
        )
        let audioClip = MediaClip(
            asset: .audio(audioURL),
            timelineRange: ClipTimeRange(startSeconds: 0, durationSeconds: 5),
            sourceRange: ClipTimeRange(startSeconds: 0, durationSeconds: 5)
        )
        let textClip = MediaClip(
            id: textClipId,
            asset: .text(textDescriptor),
            timelineRange: ClipTimeRange(startSeconds: 0, durationSeconds: 3),
            sourceRange: ClipTimeRange(startSeconds: 0, durationSeconds: 3),
            transform: .identity,
            opacity: 1
        )

        let overlayTrack = MediaTrack(trackType: .overlay, clips: [textClip])
        let audioTrack = MediaTrack(trackType: .audio, clips: [audioClip])
        let videoTrack = MediaTrack(trackType: .video, clips: [videoClip])
        let project = EditingProject(name: "Sync", tracks: [overlayTrack, audioTrack, videoTrack])

        let sut = EditorViewModel(project: project)
        let canvasTransform = TransformEffect(
            normalizedCenter: CGPoint(x: 0.22, y: 0.41),
            normalizedSize: CGSize(width: 0.5, height: 0.1),
            normalizedScale: 1.1,
            rotationAngle: 0.15
        )
        sut.updateOverlayTransform(clipId: textClipId, transform: canvasTransform)

        var timelineTracks = project.tracks
        guard let audioTrackIndex = timelineTracks.firstIndex(where: { $0.trackType == .audio }),
              timelineTracks[audioTrackIndex].clips.indices.contains(0)
        else {
            XCTFail("Expected an audio track with one clip")
            return
        }
        timelineTracks[audioTrackIndex].clips[0].timelineRange = ClipTimeRange(
            startSeconds: 1,
            durationSeconds: 4
        )

        _ = sut.syncTracksFromTimeline(timelineTracks)

        let syncedTextClip = try XCTUnwrap(
            sut.projectSnapshot().tracks
                .flatMap(\.clips)
                .first { $0.id == textClipId }
        )
        XCTAssertEqual(syncedTextClip.transform, canvasTransform)
        XCTAssertEqual(syncedTextClip.timelineRange.startSeconds, 0, accuracy: 1e-6)
    }

    @MainActor
    func testCompositionBuilderBuildsEmptyProject() async throws {
        let sut = CompositionBuilder()
        let project = EditingProject(name: "Test Empty")
        let result = try await sut.build(from: project, options: .previewDefault)

        XCTAssertIdentical(result.playerItem.asset as AnyObject?, result.composition as AnyObject?)
        XCTAssertTrue(result.composition.tracks(withMediaType: .video).isEmpty)
        XCTAssertNil(result.playerItem.videoComposition)
        XCTAssertNil(result.audioMix)
        XCTAssertTrue(result.overlayLayers.isEmpty)
        XCTAssertEqual(result.composition.duration.seconds, 0, accuracy: 1e-6)
    }
}
