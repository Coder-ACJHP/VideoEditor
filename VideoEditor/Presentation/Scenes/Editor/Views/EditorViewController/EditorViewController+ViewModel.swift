//
// EditorViewController+ViewModel
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import UIKit

extension EditorViewController: EditorViewModelDelegate {

    func editorViewModelDidRequestTimelineReload(_ viewModel: EditorViewModel) {
        timelineView.configure(with: viewModel.projectSnapshot())
        syncCanvasOverlaysFromProject()
    }

    func editorViewModel(_ viewModel: EditorViewModel, didUpdateToolbarTotalDuration formatted: String) {
        toolbarView.setTotalDuration(formatted)
    }
}
