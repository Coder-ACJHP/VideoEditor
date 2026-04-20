//
// EditorViewController+Features
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import CoreMedia
import UIKit

extension EditorViewController: EditorFeaturesViewDelegate {

    func featuresView(_ view: EditorFeaturesView, didSelectItem item: FeatureItem) {
        if item.id == "canvasBg" {
            presentCanvasBackgroundBottomSheet()
            return
        }
        if item.id == "audio" {
            presentAudioBottomSheet()
            return
        }
        if item.id == "text" {
            presentTextBottomSheet()
            return
        }
        if item.id == "textEdit" {
            guard let clipId = renderView.activeOverlayClipId,
                  viewModel.textOverlayDescriptor(for: clipId) != nil
            else { return }
            presentTextEditSheet(for: clipId)
            return
        }
        if item.id == "delete" {
            guard let clipId = selectedTimelineClipId else { return }
            presentDeleteSelectedClipConfirmation(clipId: clipId)
            return
        }
        if item.id == "duplicate" {
            guard let clipId = selectedTimelineClipId,
                  let newClip = viewModel.duplicateClip(withId: clipId)
            else { return }
            let end = viewModel.projectSnapshot().totalDuration.seconds
            latestPlaybackTimelineSeconds = min(max(0, latestPlaybackTimelineSeconds), max(end, 0))
            // Reuses the same path as a user tap: selection, text overlay focus, and sub menu.
            timelineView.selectClipOnTimeline(withId: newClip.id)
            let resumeSeconds = latestPlaybackTimelineSeconds
            Task { [weak self] in
                guard let self else { return }
                await self.playbackManager.loadPreview(
                    project: self.viewModel.projectSnapshot(),
                    compositionGeneration: self.viewModel.previewCompositionGeneration,
                    in: self.renderView
                )
                self.playbackManager.seek(to: resumeSeconds)
            }
            return
        }
        guard let presentation = EditorFeatureSheetPresentationMapper.presentation(for: item) else {
            print("Feature view didSelect item: \(item)")
            return
        }
        router.presentBottomSheet(
            to: presentation.route,
            config: presentation.configuration,
            animated: true
        )
    }

    func featuresViewDidTapBack(_ view: EditorFeaturesView) {
        selectedTimelineClipId = nil
        timelineView.deselectAllTracks()
    }
}

extension EditorViewController {

    func presentDeleteSelectedClipConfirmation(clipId: UUID) {
        let alert = UIAlertController(
            title: String(localized: "Delete clip?"),
            message: String(localized: "This clip will be removed from the timeline."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String(localized: "Delete"), style: .destructive) { [weak self] _ in
            self?.performDeleteClip(withId: clipId)
        })
        present(alert, animated: true)
    }

    func performDeleteClip(withId clipId: UUID) {
        viewModel.removeClip(withId: clipId)
        selectedTimelineClipId = nil
        timelineView.deselectAllTracks()
        syncCanvasOverlaysFromProject()

        let end = viewModel.projectSnapshot().totalDuration.seconds
        latestPlaybackTimelineSeconds = min(max(0, latestPlaybackTimelineSeconds), max(end, 0))

        let resumeSeconds = latestPlaybackTimelineSeconds
        Task { [weak self] in
            guard let self else { return }
            await self.playbackManager.loadPreview(
                project: self.viewModel.projectSnapshot(),
                compositionGeneration: self.viewModel.previewCompositionGeneration,
                in: self.renderView
            )
            self.playbackManager.seek(to: resumeSeconds)
        }
    }
}
