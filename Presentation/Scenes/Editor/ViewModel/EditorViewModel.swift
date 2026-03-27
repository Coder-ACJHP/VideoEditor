//
//  EditorViewModel.swift
//  VideoEditor
//
//  Owns working track state and editor session orchestration.
//  The view controller binds UI; domain rules for scratch clip insertion live here.
//

import CoreMedia
import Foundation

// MARK: - Delegate

@MainActor
protocol EditorViewModelDelegate: AnyObject {
    func editorViewModelDidRequestTimelineReload(_ viewModel: EditorViewModel)
    func editorViewModel(_ viewModel: EditorViewModel, didUpdateToolbarTotalDuration formatted: String)
}

// MARK: - ViewModel

@MainActor
final class EditorViewModel {

    weak var delegate: EditorViewModelDelegate?

    private let baseProject: EditingProject
    private var workingTracks: [MediaTrack]
    private let testMediaLocator: BundledTestMediaLocating
    private let textRasterizer: EditorScratchTextImageRasterizing

    /// Full initializer for tests / custom dependencies.
    init(
        project: EditingProject,
        testMediaLocator: BundledTestMediaLocating,
        textRasterizer: EditorScratchTextImageRasterizing
    ) {
        self.baseProject = project
        self.workingTracks = project.tracks
        self.testMediaLocator = testMediaLocator
        self.textRasterizer = textRasterizer
    }

    /// App / router entry — default services are constructed on the main actor (not in a default argument).
    convenience init(project: EditingProject) {
        self.init(
            project: project,
            testMediaLocator: BundledTestMediaLocator(),
            textRasterizer: EditorScratchTextImageRasterizer()
        )
    }

    // MARK: - Navigation / chrome

    var projectDisplayName: String { baseProject.name }

    // MARK: - Lifecycle

    func start() {
        delegate?.editorViewModelDidRequestTimelineReload(self)
        delegate?.editorViewModel(self, didUpdateToolbarTotalDuration: formattedProjectEndTime())
    }

    func formattedScrubTime(seconds: Double) -> String {
        TimelineClockFormatter.string(fromSeconds: seconds)
    }

    func projectSnapshot() -> EditingProject {
        EditingProject(
            id: baseProject.id,
            name: baseProject.name,
            creationDate: baseProject.creationDate,
            lastModifiedDate: Date(),
            tracks: workingTracks,
            exportSettings: baseProject.exportSettings
        )
    }

    // MARK: - Timeline sync

    func syncTracksFromTimeline(_ tracks: [MediaTrack]) {
        workingTracks = tracks
    }

    func onMasterTimelineDurationChanged(seconds: Double) {
        delegate?.editorViewModel(
            self,
            didUpdateToolbarTotalDuration: TimelineClockFormatter.string(fromSeconds: seconds)
        )
    }

    // MARK: - Features (scratch / dev inserts)

    func handleMainMenuFeatureSelection(_ item: FeatureItem) async {
        switch item.id {
        case "audio":
            guard let url = testMediaLocator.url(resource: "Reflection", extension: "mp3") else {
                print("Missing bundled test media: Reflection.mp3")
                return
            }
            let asset: AssetIdentifier = .audio(url)
            let duration = await AssetDurationResolver.sourceDuration(for: asset) ?? 5
            await appendClip(to: .audio, asset: asset, duration: duration)

        case "text":
            do {
                let url = try textRasterizer.makeTemporaryPNGURL(text: "Sample Text")
                await appendClip(to: .overlay, asset: .image(url), duration: 3)
            } catch {
                print("Failed to generate temporary text image: \(error)")
            }

        case "sticker":
            guard let url = testMediaLocator.url(resource: "img1", extension: "jpg") else {
                print("Missing bundled test media: img1.jpg")
                return
            }
            await appendClip(to: .overlay, asset: .image(url), duration: 3)

        default:
            print("Feature view didSelect item: \(item)")
        }
    }

    // MARK: - Private

    private func formattedProjectEndTime() -> String {
        TimelineClockFormatter.string(fromSeconds: projectSnapshot().totalDuration.seconds)
    }

    private var masterTrackEndSeconds: Double? {
        let videoTracks = workingTracks.filter { $0.trackType == .video }
        guard !videoTracks.isEmpty else { return nil }
        let end = videoTracks
            .flatMap(\.clips)
            .map(\.timelineRange.endSeconds)
            .max() ?? 0
        return end > 0 ? end : nil
    }

    /// By default each inserted test media gets its own dedicated track lane.
    private func appendClip(
        to trackType: MediaTrack.TrackType,
        asset: AssetIdentifier,
        duration: Double,
        alwaysCreateNewTrack: Bool = true
    ) async {
        let minDuration = TimelineConfiguration.default.minClipDuration
        let safeDuration = max(duration, minDuration)
        let timelineDuration: Double
        if trackType == .video {
            timelineDuration = safeDuration
        } else if let masterDuration = masterTrackEndSeconds {
            timelineDuration = min(safeDuration, masterDuration)
        } else {
            timelineDuration = safeDuration
        }
        let sourceDuration = await AssetDurationResolver.sourceDuration(for: asset) ?? safeDuration
        let sourceRange = ClipTimeRange(startSeconds: 0, durationSeconds: sourceDuration)

        if alwaysCreateNewTrack {
            let range = ClipTimeRange(startSeconds: 0, durationSeconds: timelineDuration)
            let clip = MediaClip(asset: asset, timelineRange: range, sourceRange: sourceRange)
            workingTracks.append(MediaTrack(trackType: trackType, clips: [clip]))
            publishTimelineAndToolbar()
            return
        }

        if let existingIndex = workingTracks.firstIndex(where: { $0.trackType == trackType }) {
            let start = workingTracks[existingIndex].clips.map(\.timelineRange.endSeconds).max() ?? 0
            let range = ClipTimeRange(startSeconds: start, durationSeconds: timelineDuration)
            let clip = MediaClip(asset: asset, timelineRange: range, sourceRange: sourceRange)
            workingTracks[existingIndex].clips.append(clip)
        } else {
            let range = ClipTimeRange(startSeconds: 0, durationSeconds: timelineDuration)
            let clip = MediaClip(asset: asset, timelineRange: range, sourceRange: sourceRange)
            workingTracks.append(MediaTrack(trackType: trackType, clips: [clip]))
        }

        publishTimelineAndToolbar()
    }

    private func publishTimelineAndToolbar() {
        delegate?.editorViewModelDidRequestTimelineReload(self)
        delegate?.editorViewModel(self, didUpdateToolbarTotalDuration: formattedProjectEndTime())
    }
}
