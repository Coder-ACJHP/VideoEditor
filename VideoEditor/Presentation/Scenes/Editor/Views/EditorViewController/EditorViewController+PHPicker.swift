//
// EditorViewController+PHPicker
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import PhotosUI
import UIKit

extension EditorViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let imported = try await self.mediaImportService.importPickedItems(results)
                await self.viewModel.appendImportedMediaToMasterVideoTrack(imported)
                let resumeSeconds = self.latestPlaybackTimelineSeconds
                await self.playbackManager.loadPreview(
                    project: self.viewModel.projectSnapshot(),
                    compositionGeneration: self.viewModel.previewCompositionGeneration,
                    in: self.renderView
                )
                self.playbackManager.seek(to: resumeSeconds)
                self.syncCanvasOverlaysFromProject()
            } catch {
                self.presentEditorImportAlert(error.localizedDescription)
            }
        }
    }
}
