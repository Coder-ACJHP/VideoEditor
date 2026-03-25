//
//  ExportSettings.swift
//  VideoEditor
//
//  Dışa aktarma işlemi için kalite ve format ayarları.
//  Her değer doğrudan AVFoundation sabitlerine eşlenmiştir,
//  bu sayede engine bu modeli doğrudan kullanabilir.

import AVFoundation

struct ExportSettings: Codable, Equatable {

    var preset: ExportPreset
    var fileType: ExportFileType

    enum ExportPreset: String, Codable, CaseIterable {
        case low      // 640×480
        case medium   // 1280×720  (HD)
        case high     // 1920×1080 (Full HD)
        case highest  // Cihazın desteklediği en yüksek çözünürlük (4K vb.)

        /// AVAssetExportSession'a aktarılacak preset string.
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

    /// Varsayılan: Full HD, MP4.
    static let `default` = ExportSettings(preset: .high, fileType: .mp4)
}
