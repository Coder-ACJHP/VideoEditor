//
// EditorViewController+RenderView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import UIKit

extension EditorViewController: EditorRenderViewOverlayDelegate {

    func editorRenderView(_ renderView: EditorRenderView, clipId: UUID, didUpdateTransform transform: TransformEffect) {
        if let draft = textSheetDraft, draft.id == clipId {
            textSheetDraft = (draft.id, draft.descriptor, transform)
            return
        }
        viewModel.updateOverlayTransform(clipId: clipId, transform: transform)
        refreshCanvasOverlays()
    }

    func editorRenderView(_ renderView: EditorRenderView, didActivateClip clipId: UUID) {
        timelineView.selectClipOnTimeline(withId: clipId)
    }
}

extension EditorViewController: EditorRenderViewDelegate {

    func renderView(_ renderView: EditorRenderView, didRequestToggleSizeWithExpanding isExpanding: Bool) {
        let newRatio = isExpanding ? expandedHeightRatio : collapsedHeightRatio

        renderViewHeightConstraint?.isActive = false
        let newConstraint = renderView.heightAnchor.constraint(
            equalTo: view.heightAnchor,
            multiplier: newRatio
        )
        newConstraint.isActive = true
        renderViewHeightConstraint = newConstraint

        featuresHeightConstraint?.constant = isExpanding ? 0 : EditorFeaturesView.preferredHeight
        featuresView.alpha = isExpanding ? 0 : 1
        featuresView.isUserInteractionEnabled = !isExpanding
        if !isExpanding {
            featuresView.showMainMenu(animated: false)
        }

        timelineView.setExpandedPreviewMode(isExpanding, animated: true)
        renderView.setExpanded(isExpanding)

        UIView.animate(
            withDuration: 1.0,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.15,
            options: [.curveEaseInOut, .allowUserInteraction, .layoutSubviews]
        ) { self.view.layoutIfNeeded() }
    }
}
