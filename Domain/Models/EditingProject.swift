//
// EditingProject
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Root model for a user-created video project.
//  Because it is `Codable`, it can be saved to disk and reloaded so the user
//  can continue where they left off.
//
//  Persistence strategy:
//  - Each project is written to its own JSON file (.videoproj).
//  - Core Data stores only the project index (id, name, lastModifiedDate, thumbnailURL)
//    so nested struct payloads do not require relational normalization.

import CoreMedia
import Foundation

/// Excludes this domain value type from the target’s default MainActor isolation
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION`), keeping `Hashable & Sendable` usable as a diffable item ID.
nonisolated struct EditingProject: Identifiable, Hashable, Sendable {

    let id: UUID
    var name: String
    let creationDate: Date
    /// Must be updated whenever the project changes; also used as the last-saved timestamp.
    var lastModifiedDate: Date

    /// Ordered list of tracks.
    /// Index order defines z-order: higher index renders on top.
    var tracks: [MediaTrack]

    /// Preview / composition frame behind all video layers.
    var canvasBackground: CanvasBackgroundSettings

    var exportSettings: ExportSettings

    // MARK: - Computed Properties

    /// Total duration from the latest end time across all tracks.
    var totalDuration: CMTime {
        let maxEnd = tracks
            .flatMap(\.clips)
            .map(\.timelineRange.endSeconds)
            .max() ?? 0
        return CMTime(seconds: maxEnd, preferredTimescale: 600)
    }

    /// Whether the project has no clips at all.
    var isEmpty: Bool {
        tracks.flatMap(\.clips).isEmpty
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        creationDate: Date = Date(),
        lastModifiedDate: Date = Date(),
        tracks: [MediaTrack] = [],
        canvasBackground: CanvasBackgroundSettings = .default,
        exportSettings: ExportSettings = .default
    ) {
        self.id = id
        self.name = name
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
        self.tracks = tracks
        self.canvasBackground = canvasBackground
        self.exportSettings = exportSettings
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static func == (lhs: EditingProject, rhs: EditingProject) -> Bool { lhs.id == rhs.id }
}

// MARK: - Codable (migrates legacy `canvasBackgroundColorHex`)

extension EditingProject: Codable {

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case creationDate
        case lastModifiedDate
        case tracks
        case exportSettings
        case canvasBackground
        case canvasBackgroundColorHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
        lastModifiedDate = try c.decode(Date.self, forKey: .lastModifiedDate)
        tracks = try c.decode([MediaTrack].self, forKey: .tracks)
        exportSettings = try c.decodeIfPresent(ExportSettings.self, forKey: .exportSettings) ?? .default

        if let bg = try c.decodeIfPresent(CanvasBackgroundSettings.self, forKey: .canvasBackground) {
            canvasBackground = bg
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .canvasBackgroundColorHex) {
            canvasBackground = CanvasBackgroundSettings(style: .solid, primaryHex: legacy, secondaryHex: nil)
        } else {
            canvasBackground = .default
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(creationDate, forKey: .creationDate)
        try c.encode(lastModifiedDate, forKey: .lastModifiedDate)
        try c.encode(tracks, forKey: .tracks)
        try c.encode(exportSettings, forKey: .exportSettings)
        try c.encode(canvasBackground, forKey: .canvasBackground)
    }
}
