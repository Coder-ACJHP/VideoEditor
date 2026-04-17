//
// MovieExportError
// VideoEditor
//

import Foundation

/// Domain-level failures for timeline → file → Photo Library export.
enum MovieExportError: LocalizedError, Equatable, Sendable {
    case photoLibraryPermissionDenied
    case compositionBuildFailed
    case noVideoTrackToExport
    case exportSessionCreationFailed
    case exportFailed(statusDescription: String)
    case saveToPhotoLibraryFailed

    var errorDescription: String? {
        switch self {
        case .photoLibraryPermissionDenied:
            return String(localized: "Photo library access is required to save the video.")
        case .compositionBuildFailed:
            return String(localized: "Could not build the video from your timeline.")
        case .noVideoTrackToExport:
            return String(localized: "Add at least one video or image clip before exporting.")
        case .exportSessionCreationFailed:
            return String(localized: "Could not start video export on this device.")
        case .exportFailed(let statusDescription):
            return statusDescription
        case .saveToPhotoLibraryFailed:
            return String(localized: "The video was exported but could not be saved to your library.")
        }
    }
}
