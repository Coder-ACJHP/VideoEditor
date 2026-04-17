//
// PhotoLibraryMovieExporterTests
// VideoEditorTests
//

//  Early export failures (permission, composition, empty timeline) without touching AVAssetExportSession or Photos.
//

import AVFoundation
import XCTest
@testable import VideoEditor

@MainActor
final class PhotoLibraryMovieExporterTests: XCTestCase {

    private final class StubMediaPermissions: MediaDevicePermissionProviding, @unchecked Sendable {
        let addAccessError: Error?

        init(addAccessError: Error? = nil) {
            self.addAccessError = addAccessError
        }

        func ensurePhotoLibraryReadAccess() async throws {}

        func ensurePhotoLibraryAddAccess() async throws {
            if let addAccessError {
                throw addAccessError
            }
        }

        func ensureCameraAccess() async throws {}
    }

    private final class StubCompositionBuilder: CompositionBuilding {
        enum Outcome {
            case success(CompositionBuildResult)
            case throwOnBuild
        }

        let outcome: Outcome

        init(outcome: Outcome) {
            self.outcome = outcome
        }

        func build(from project: EditingProject, options: CompositionBuildOptions) async throws -> CompositionBuildResult {
            switch outcome {
            case .success(let result):
                return result
            case .throwOnBuild:
                throw NSError(domain: "PhotoLibraryMovieExporterTests", code: 1)
            }
        }
    }

    private func compositionWithNoVideoTracks() -> CompositionBuildResult {
        let composition = AVMutableComposition()
        let item = AVPlayerItem(asset: composition)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: 64, height: 64)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        return CompositionBuildResult(
            playerItem: item,
            composition: composition,
            videoComposition: videoComposition,
            overlayLayers: [],
            audioMix: nil
        )
    }

    func testExportThrowsWhenPhotoLibraryAddPermissionDenied() async {
        let exporter = PhotoLibraryMovieExporter(
            compositionBuilder: StubCompositionBuilder(outcome: .throwOnBuild),
            mediaPermissions: StubMediaPermissions(addAccessError: MediaPermissionError.photoLibraryAddDenied)
        )
        let project = EditingProject(name: "P", tracks: [])

        do {
            _ = try await exporter.exportMovieToPhotoLibrary(
                project: project,
                configuration: MovieExportConfiguration(fileType: .mov),
                progress: nil
            )
            XCTFail("Expected photoLibraryPermissionDenied")
        } catch let error as MovieExportError {
            XCTAssertEqual(error, .photoLibraryPermissionDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExportThrowsWhenCompositionBuildFails() async {
        let exporter = PhotoLibraryMovieExporter(
            compositionBuilder: StubCompositionBuilder(outcome: .throwOnBuild),
            mediaPermissions: StubMediaPermissions(addAccessError: nil)
        )
        let project = EditingProject(name: "P", tracks: [])

        do {
            _ = try await exporter.exportMovieToPhotoLibrary(
                project: project,
                configuration: MovieExportConfiguration(fileType: .mov),
                progress: nil
            )
            XCTFail("Expected compositionBuildFailed")
        } catch let error as MovieExportError {
            XCTAssertEqual(error, .compositionBuildFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExportThrowsWhenCompositionHasNoVideoTrack() async {
        let stubResult = compositionWithNoVideoTracks()
        let exporter = PhotoLibraryMovieExporter(
            compositionBuilder: StubCompositionBuilder(outcome: .success(stubResult)),
            mediaPermissions: StubMediaPermissions(addAccessError: nil)
        )
        let project = EditingProject(name: "P", tracks: [])

        do {
            _ = try await exporter.exportMovieToPhotoLibrary(
                project: project,
                configuration: MovieExportConfiguration(fileType: .mov),
                progress: nil
            )
            XCTFail("Expected noVideoTrackToExport")
        } catch let error as MovieExportError {
            XCTAssertEqual(error, .noVideoTrackToExport)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
