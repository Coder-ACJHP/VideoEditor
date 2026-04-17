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
