//
// EditorViewController+Toolbar
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import UIKit

extension EditorViewController: EditorToolbarViewDelegate {

    func toolbarViewDidTapPlayPause(_ toolbar: EditorToolbarView) {
        let shouldPlay = !toolbar.isPlaying
        toolbar.setPlaying(shouldPlay)

        Task { [weak self] in
            guard let self else { return }
            if shouldPlay {
                // Deselect all tracks
                timelineView.deselectAllTracks()
                // Play composition
                await self.playbackManager.play(
                    project: self.viewModel.projectSnapshot(),
                    compositionGeneration: self.viewModel.previewCompositionGeneration,
                    in: self.renderView
                )
            } else {
                self.playbackManager.pause()
            }
        }
    }

    func toolbarViewDidTapUndo(_ toolbar: EditorToolbarView) {
        // TODO: Connect to the command stack.
    }

    func toolbarViewDidTapRedo(_ toolbar: EditorToolbarView) {
        // TODO: Connect to the command stack.
    }
}
