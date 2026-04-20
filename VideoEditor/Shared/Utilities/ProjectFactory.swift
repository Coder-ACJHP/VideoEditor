//
// ProjectFactory
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Central place to construct domain models.
//  Keeps view models free of UI / import details and makes project-creation rules testable.

import AVFoundation
import Foundation

enum ProjectFactory {

    nonisolated static var newProjectName: String {
        get {
            let newCount = createdProjectsCount + 1
            return "New Project \(newCount)"
        }
    }

    nonisolated private static let projectCountKey = "createdAppCount"

    nonisolated private static var createdProjectsCount: Int {
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

    /// Clears the auto-increment used by `newProjectName` so UI tests get predictable titles.
    static func resetProjectNameCounterForUITesting() {
        UserDefaults.standard.removeObject(forKey: projectCountKey)
    }

    static func makeNewProject(
        name: String = Self.newProjectName,
        importedMedia: [ImportedMedia]
    ) async -> EditingProject {
        var timelineCursor: Double = 0
        var clips: [MediaClip] = []
        clips.reserveCapacity(importedMedia.count)

        for item in importedMedia {
            switch item.asset.mediaType {
            case .image, .text:
                let clip = MediaClip(
                    imageAsset: item.asset,
                    timelineOffset: timelineCursor,
                    duration: MediaClip.defaultImageDuration
                )
                clips.append(clip)
                timelineCursor += MediaClip.defaultImageDuration
            case .video:
                var duration = max(0, item.durationSeconds ?? 0)
                if duration <= 0, case .video(let url) = item.asset {
                    let urlAsset = AVURLAsset(url: url)
                    if let seconds = try? await urlAsset.load(.duration).seconds,
                     seconds.isFinite, seconds > 0 { duration = seconds }
                }
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
