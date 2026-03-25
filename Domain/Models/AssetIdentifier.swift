//
//  AssetIdentifier.swift
//  VideoEditor
//
//  Kaynak medyanın nereden geldiğini ve ne tür bir medya olduğunu tek bir
//  enum altında birleştirir. Engine, bu enum'a switch yaparak hangi
//  rendering pipeline'ını (AVURLAsset, PHAsset fetch, CALayer compositing)
//  kullanacağına karar verir.

import Foundation

nonisolated enum AssetIdentifier: Codable, Hashable {

    /// Uygulama sandbox'ındaki yerel video dosyası.
    case video(URL)
    /// Uygulama sandbox'ındaki yerel ses dosyası.
    case audio(URL)
    /// Uygulama sandbox'ındaki yerel fotoğraf dosyası.
    /// Engine, still-frame olduğunu bu case'den anlar; sourceRange uygulanmaz.
    case image(URL)

    /// Photos Library'den seçilen video (localIdentifier).
    case phAssetVideo(String)
    /// Photos Library'den seçilen fotoğraf (localIdentifier).
    case phAssetImage(String)

    // MARK: - Derived

    var mediaType: MediaType {
        switch self {
        case .video, .phAssetVideo: return .video
        case .audio:                return .audio
        case .image, .phAssetImage: return .image
        }
    }

    enum MediaType: String, Codable {
        /// Oynatılabilir video akışı; sourceRange ve timelineRange tam anlamıyla geçerlidir.
        case video
        /// Yalnızca ses; video track'e eklenmez.
        case audio
        /// Still frame; sourceRange engine tarafından görmezden gelinir,
        /// display süresi timelineRange.durationSeconds'dan alınır.
        case image
    }
}
