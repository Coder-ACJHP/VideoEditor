//
//  ProjectFactory.swift
//  VideoEditor
//
//  Domain model üretimini tek bir noktada toplar.
//  Bu sayede ViewModel'ler UI / import detaylarından bağımsız kalır ve
//  proje oluşturma kuralları test edilebilir hale gelir.

import Foundation

enum ProjectFactory {

    static var newProjectName: String {
        get {
            let newCount = createdProjectsCount + 1
            return "New Project \(newCount)"
        }
    }
    
    private static let projectCountKey = "createdAppCount"
    
    private static var createdProjectsCount: Int {
        get { UserDefaults.standard.integer(forKey: projectCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: projectCountKey) }
    }
    
    struct ImportedMedia: Equatable {
        let asset: AssetIdentifier
        let durationSeconds: Double?

        init(asset: AssetIdentifier, durationSeconds: Double? = nil) {
            self.asset = asset
            self.durationSeconds = durationSeconds
        }
    }

    static func makeNewProject(
        name: String = Self.newProjectName,
        importedMedia: [ImportedMedia]
    ) -> EditingProject {
        var timelineCursor: Double = 0
        var clips: [MediaClip] = []
        clips.reserveCapacity(importedMedia.count)

        for item in importedMedia {
            switch item.asset.mediaType {
            case .image:
                let clip = MediaClip(
                    imageAsset: item.asset,
                    timelineOffset: timelineCursor,
                    duration: MediaClip.defaultImageDuration
                )
                clips.append(clip)
                timelineCursor += MediaClip.defaultImageDuration
            case .video:
                let duration = max(0, item.durationSeconds ?? 0)
                let source = ClipTimeRange(startSeconds: 0, durationSeconds: duration)
                let timeline = ClipTimeRange(startSeconds: timelineCursor, durationSeconds: duration)
                let clip = MediaClip(asset: item.asset, timelineRange: timeline, sourceRange: source)
                clips.append(clip)
                timelineCursor += duration
            case .audio:
                continue
            }
        }

        let track = MediaTrack(trackType: .video, clips: clips)
        createdProjectsCount += 1
        return EditingProject(name: name, tracks: [track])
    }
}
