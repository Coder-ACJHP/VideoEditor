//
// ExportSettings
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Quality and container settings for export.
//  Values map directly to AVFoundation presets so the engine can use this model as-is.

import AVFoundation

nonisolated struct ExportSettings: Codable, Equatable, Sendable {

    var preset: ExportPreset
    var fileType: ExportFileType

    enum ExportPreset: String, Codable, CaseIterable {
        case low      // 640×480
        case medium   // 1280×720  (HD)
        case high     // 1920×1080 (Full HD)
        case highest  // Best resolution the device supports (e.g. 4K).

        /// Preset string passed to `AVAssetExportSession`.
        var avPreset: String {
            switch self {
            case .low:     return AVAssetExportPresetLowQuality
            case .medium:  return AVAssetExportPreset1280x720
            case .high:    return AVAssetExportPreset1920x1080
            case .highest: return AVAssetExportPresetHighestQuality
            }
        }
    }

    enum ExportFileType: String, Codable, CaseIterable {
        case mp4
        case mov

        var avFileType: AVFileType {
            switch self {
            case .mp4: return .mp4
            case .mov: return .mov
            }
        }

        var fileExtension: String { rawValue }
    }

    /// Default: Full HD, QuickTime (`.mov`) for gallery export compatibility.
    static let `default` = ExportSettings(preset: .high, fileType: .mov)
}
