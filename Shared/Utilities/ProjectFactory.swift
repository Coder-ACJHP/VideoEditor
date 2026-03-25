//
//  ProjectFactory.swift
//  VideoEditor
//
//  Domain model üretimini tek bir noktada toplar.
//  Bu sayede ViewModel'ler UI / import detaylarından bağımsız kalır ve
//  proje oluşturma kuralları test edilebilir hale gelir.

import Foundation

enum ProjectFactory {

    struct ImportedMedia: Equatable {
        let asset: AssetIdentifier
        let durationSeconds: Double?

        init(asset: AssetIdentifier, durationSeconds: Double? = nil) {
            self.asset = asset
            self.durationSeconds = durationSeconds
        }
    }

    static func makeNewProject(
        name: String = "New Project",
        importedMedia: [ImportedMedia]
    ) -> EditingProject {
        // Başlangıç: tek bir video track içine, sırayla yerleştir.
        // Audio import Landing'de yok; Editor içinde eklenecek.
        var timelineCursor: Double = 0
        var clips: [VideoClip] = []
        clips.reserveCapacity(importedMedia.count)

        for item in importedMedia {
            switch item.asset.mediaType {
            case .image:
                let clip = VideoClip(
                    imageAsset: item.asset,
                    timelineOffset: timelineCursor,
                    duration: VideoClip.defaultImageDuration
                )
                clips.append(clip)
                timelineCursor += VideoClip.defaultImageDuration

            case .video:
                let duration = max(0, item.durationSeconds ?? 0)
                let source = ClipTimeRange(startSeconds: 0, durationSeconds: duration)
                let timeline = ClipTimeRange(startSeconds: timelineCursor, durationSeconds: duration)
                let clip = VideoClip(asset: item.asset, timelineRange: timeline, sourceRange: source)
                clips.append(clip)
                timelineCursor += duration

            case .audio:
                // Landing'de audio import etmiyoruz.
                continue
            }
        }

        let track = VideoTrack(trackType: .video, clips: clips)
        return EditingProject(name: name, tracks: [track])
    }
}
