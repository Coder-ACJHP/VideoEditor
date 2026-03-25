//
//  MediaImportService.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 25.03.2026.
//

import Foundation
import PhotosUI
import UniformTypeIdentifiers

// Domain/Protocols/MediaImportService.swift
protocol MediaImportService {
    /// Dışarıdan gelen bir medyayı uygulamanın güvenli alanına kopyalar.
    func importPickedItems(_ results: [PHPickerResult]) async throws -> [ProjectFactory.ImportedMedia]
}
