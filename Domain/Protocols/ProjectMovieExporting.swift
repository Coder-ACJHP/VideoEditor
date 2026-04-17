//
// ProjectMovieExporting
// VideoEditor
//

import Foundation

/// Per-session container choice (does not mutate `EditingProject` on disk).
nonisolated struct MovieExportConfiguration: Equatable, Sendable {

    var fileType: ExportSettings.ExportFileType

    /// Aligns with the project’s current export container when opening the screen.
    static func `default`(matching project: EditingProject) -> MovieExportConfiguration {
        MovieExportConfiguration(fileType: project.exportSettings.fileType)
    }
}

/// Output of a successful export + library save; `fileURL` stays valid until the UI deletes it.
nonisolated struct ExportedMovieDelivery: Sendable {

    let fileURL: URL
}

/// Writes the editing timeline to a movie file and adds it to the user’s photo library.
@MainActor
protocol ProjectMovieExporting: AnyObject {

    func exportMovieToPhotoLibrary(
        project: EditingProject,
        configuration: MovieExportConfiguration,
        progress: (@MainActor (Double) -> Void)?
    ) async throws -> ExportedMovieDelivery
}
