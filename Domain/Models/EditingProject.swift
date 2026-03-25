//
//  EditingProject.swift
//  VideoEditor
//
//  Kullanıcının oluşturduğu video projesinin kök modeli.
//  Codable olduğu için diske kaydedilip yüklenebilir;
//  bu sayede kullanıcı uygulamanın kaldığı yerden devam edebilir.
//
//  Persistence stratejisi:
//  - Her proje ayrı bir JSON dosyasına (.videoproj) yazılır.
//  - Core Data yalnızca proje indeksi (id, name, lastModifiedDate, thumbnailURL)
//    için kullanılır, böylece iç içe struct yapısı normalizasyon gerektirmez.

import CoreMedia
import Foundation

struct EditingProject: Identifiable, Codable {

    let id: UUID
    var name: String
    let creationDate: Date
    /// Proje her değiştirildiğinde güncellenmelidir; son kaydetme zamanı olarak da kullanılır.
    var lastModifiedDate: Date

    /// Sıralı track listesi.
    /// İndeks sırası z-order'ı belirler: yüksek indeks = üstte render edilir.
    var tracks: [VideoTrack]

    var exportSettings: ExportSettings

    // MARK: - Computed Properties

    /// Tüm track'lerdeki en geç bitiş noktasından hesaplanan toplam süre.
    var totalDuration: CMTime {
        let maxEnd = tracks
            .flatMap(\.clips)
            .map(\.timelineRange.endSeconds)
            .max() ?? 0
        return CMTime(seconds: maxEnd, preferredTimescale: 600)
    }

    /// Projede hiç clip yok mu?
    var isEmpty: Bool {
        tracks.flatMap(\.clips).isEmpty
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        creationDate: Date = Date(),
        lastModifiedDate: Date = Date(),
        tracks: [VideoTrack] = [],
        exportSettings: ExportSettings = .default
    ) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
        self.tracks = tracks
        self.exportSettings = exportSettings
    }
}
