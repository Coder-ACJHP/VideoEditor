//
// EditorViewController+Timeline
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import PhotosUI
import UIKit

extension EditorViewController: EditorTimelineViewDelegate {

    func timelineView(_ timeline: EditorTimelineView, didScrubToTime seconds: Double) {
        latestPlaybackTimelineSeconds = max(0, seconds)
        viewModel.notePlaybackTimelineSeconds(latestPlaybackTimelineSeconds)
        toolbarView.setCurrentTime(viewModel.formattedScrubTime(seconds: seconds))
        playbackManager.seek(to: seconds)
        refreshCanvasOverlays()
    }

    func timelineView(
        _ timeline: EditorTimelineView,
        didSelectClipWithId clipId: UUID,
        mediaType: AssetIdentifier.MediaType,
        laneTrackType: MediaTrack.TrackType
    ) {
        selectedTimelineClipId = clipId
        let canvasTransformable = laneTrackType == .overlay && (mediaType == .text || mediaType == .image)
        if canvasTransformable {
            renderView.setActiveOverlayClipId(clipId)
        } else {
            renderView.setActiveOverlayClipId(nil)
        }
        syncCanvasOverlaysFromProject()
        featuresView.showSubMenu(items: FeatureItem.subMenuItems(for: mediaType), animated: true)
    }

    func timelineViewDidDeselectAll(_ timeline: EditorTimelineView) {
        selectedTimelineClipId = nil
        renderView.setActiveOverlayClipId(nil)
        syncCanvasOverlaysFromProject()
        featuresView.showMainMenu(animated: true)
    }

    func timelineView(_ timeline: EditorTimelineView, didExtendDurationTo seconds: Double) {
        viewModel.onMasterTimelineDurationChanged(seconds: seconds)
    }

    func timelineView(_ timeline: EditorTimelineView, didUpdateTracks tracks: [MediaTrack]) {
        let previewCompositionNeedsReload = viewModel.syncTracksFromTimeline(tracks)
        // UIKit-only overlays (text + stickers) still need a canvas refresh when timeline ranges move.
        refreshCanvasOverlays()
        guard previewCompositionNeedsReload else { return }
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

    func timelineViewDidTapAddMedia(_ timeline: EditorTimelineView) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.mediaPermissions.ensurePhotoLibraryReadAccess()
                self.presentEditorGalleryPicker()
            } catch let error as MediaPermissionError {
                self.presentEditorMediaPermissionAlert(error: error)
            } catch {
                self.presentEditorImportAlert(error.localizedDescription)
            }
        }
    }

    func timelineView(
        _ timeline: EditorTimelineView,
        didRequestTransitionPickerAfterClipAt clipIndex: Int,
        currentTransition: ClipTransition?
    ) {
        presentTransitionPickerBottomSheet(afterMasterClipAt: clipIndex, currentTransition: currentTransition)
    }
}

extension EditorViewController {

    func presentEditorGalleryPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        if ProcessInfo.processInfo.arguments.contains("-uitesting-picker-limit-3") {
            config.selectionLimit = 3
        } else {
            config.selectionLimit = 0
        }
        config.filter = .any(of: [.images, .videos])

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func presentEditorMediaPermissionAlert(error: MediaPermissionError) {
        let alert = UIAlertController(
            title: "Permission needed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if error != .cameraUnavailable, error != .photoLibraryRestricted,
           error != .photoLibraryAddRestricted, error != .cameraRestricted {
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            })
        }
        present(alert, animated: true)
    }

    func presentEditorImportAlert(_ message: String) {
        let alert = UIAlertController(
            title: "Import failed",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
