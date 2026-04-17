//
// PhotoLibraryMovieExporter
// VideoEditor
//

import AVFoundation
import Foundation
import Photos
import UniformTypeIdentifiers

@MainActor
final class PhotoLibraryMovieExporter: ProjectMovieExporting {

    private let compositionBuilder: CompositionBuilding
    private let mediaPermissions: MediaDevicePermissionProviding

    init(
        compositionBuilder: CompositionBuilding,
        mediaPermissions: MediaDevicePermissionProviding
    ) {
        self.compositionBuilder = compositionBuilder
        self.mediaPermissions = mediaPermissions
    }

    func exportMovieToPhotoLibrary(
        project: EditingProject,
        configuration: MovieExportConfiguration,
        progress: (@MainActor (Double) -> Void)?
    ) async throws -> ExportedMovieDelivery {
        do {
            try await mediaPermissions.ensurePhotoLibraryAddAccess()
        } catch {
            throw MovieExportError.photoLibraryPermissionDenied
        }

        let result: CompositionBuildResult
        do {
            result = try await compositionBuilder.build(from: project, options: .exportWithText)
        } catch {
            throw MovieExportError.compositionBuildFailed
        }

        let composition = result.composition
        let videoTracks = composition.tracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw MovieExportError.noVideoTrackToExport
        }

        let preset = project.exportSettings.preset.avPreset
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: preset) else {
            throw MovieExportError.exportSessionCreationFailed
        }

        exportSession.videoComposition = result.videoComposition
        exportSession.audioMix = result.audioMix
        exportSession.outputFileType = configuration.fileType.avFileType
        exportSession.shouldOptimizeForNetworkUse = true

        let ext = configuration.fileType.fileExtension
        let baseName = Self.sanitizedFileBaseName(from: project.name)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)-\(UUID().uuidString.prefix(8)).\(ext)")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        exportSession.outputURL = outputURL

        let progressTask = Self.startProgressPolling(session: exportSession, progress: progress)
        try await exportAsynchronously(exportSession)
        progressTask.cancel()
        progress?(1.0)

        let originalFilename = "\(baseName).\(ext)"
        do {
            try await saveVideoToPhotoLibrary(fileURL: outputURL, originalFilename: originalFilename, fileType: configuration.fileType)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw MovieExportError.saveToPhotoLibraryFailed
        }

        return ExportedMovieDelivery(fileURL: outputURL)
    }

    /// Removes characters unsafe for a single path component; empty input becomes `Export`.
    private static func sanitizedFileBaseName(from projectName: String) -> String {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Export" }

        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let parts = trimmed.components(separatedBy: invalid).filter { !$0.isEmpty }
        let joined = parts.joined(separator: "-")
        let base = joined.isEmpty ? "Export" : joined
        return String(base.prefix(80))
    }

    private static func startProgressPolling(
        session: AVAssetExportSession,
        progress: (@MainActor (Double) -> Void)?
    ) -> Task<Void, Never> {
        return Task { @MainActor in
            while !Task.isCancelled {
                let value = max(0, min(1, session.progress))
                progress?(Double(value))

                switch session.status {
                case .completed, .failed, .cancelled:
                    return
                default:
                    break
                }

                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func exportAsynchronously(_ session: AVAssetExportSession) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                let status = session.status
                let exportError = session.error
                Task { @MainActor in
                    switch status {
                    case .completed:
                        continuation.resume()
                    case .failed:
                        let message = exportError?.localizedDescription ?? String(localized: "Unknown export error")
                        continuation.resume(throwing: MovieExportError.exportFailed(statusDescription: message))
                    case .cancelled:
                        continuation.resume(throwing: MovieExportError.exportFailed(statusDescription: "Cancelled"))
                    default:
                        continuation.resume(
                            throwing: MovieExportError.exportFailed(
                                statusDescription: "Unexpected status \(status.rawValue)"
                            )
                        )
                    }
                }
            }
        }
    }

    private func saveVideoToPhotoLibrary(
        fileURL: URL,
        originalFilename: String,
        fileType: ExportSettings.ExportFileType
    ) async throws {
        let uti: String = {
            switch fileType {
            case .mov: return UTType.quickTimeMovie.identifier
            case .mp4: return UTType.mpeg4Movie.identifier
            }
        }()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = originalFilename
                options.uniformTypeIdentifier = uti
                options.shouldMoveFile = false
                request.addResource(with: .video, fileURL: fileURL, options: options)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? MovieExportError.saveToPhotoLibraryFailed)
                    }
                }
            }
        }
    }
}
