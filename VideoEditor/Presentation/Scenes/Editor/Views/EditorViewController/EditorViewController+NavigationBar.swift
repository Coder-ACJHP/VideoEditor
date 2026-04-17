//
// EditorViewController+NavigationBar
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import UIKit

extension EditorViewController: EditorNavigationBarDelegate {

    func editorNavBarDidTapClose(_ navBar: EditorNavigationBar) {
        router.pop(animated: true)
    }

    func editorNavBarDidTapTitle(_ navBar: EditorNavigationBar) {
        // TODO: Present rename / project-options action sheet.
    }

    func editorNavBarDidTapNext(_ navBar: EditorNavigationBar) {
        router.navigateToExport(with: viewModel.projectSnapshot(), animated: true)
    }
}
