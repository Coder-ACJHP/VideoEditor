//
// MediaImportService
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import Foundation
import PhotosUI
import UniformTypeIdentifiers

// Domain/Protocols/MediaImportService.swift
protocol MediaImportService {
    /// Copies picked media from the system picker into the app sandbox.
    func importPickedItems(_ results: [PHPickerResult]) async throws -> [ProjectFactory.ImportedMedia]
}
