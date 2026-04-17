//
// EditorFeatureSheetPresentationMapper
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Maps main-strip feature taps to Route + SheetConfiguration. Keeps UIKit and
//  router concerns out of EditorViewModel (presentation wiring only).
//

import UIKit

enum EditorFeatureSheetPresentationMapper {

    /// Sheet chrome for the audio picker when created by `EditorViewController` (with a selection callback).
    static func audioPickerSheetConfiguration() -> SheetConfiguration {
        SheetConfiguration(
            detents: [.large()],
            selectedIdentifier: .large,
            isDismissable: true,
            prefersScrollExpand: false,
            largestUndimmedIdentifier: .large,
            cornerRadius: 24.resp,
            prefersGrabber: true,
            reportedHeight: .zero
        )
    }

    /// Canvas background picker (solid colors + gradient presets).
    static func canvasBackgroundSheetConfiguration() -> SheetConfiguration {
        SheetConfiguration(
            detents: [.large()],
            selectedIdentifier: .large,
            isDismissable: true,
            prefersScrollExpand: true,
            largestUndimmedIdentifier: .large,
            cornerRadius: 24.resp,
            prefersGrabber: true,
            reportedHeight: .zero
        )
    }

    /// Master-track transition picker: starts at `.medium`, user can expand to `.large`.
    static func transitionPickerSheetConfiguration() -> SheetConfiguration {
        SheetConfiguration(
            detents: [.large()],
            selectedIdentifier: .large,
            isDismissable: true,
            prefersScrollExpand: true,
            largestUndimmedIdentifier: .large,
            cornerRadius: 24.resp,
            prefersGrabber: true,
            reportedHeight: .zero
        )
    }

    /// Returns route and sheet config for editor feature bottom sheets, or `nil` for unknown items.
    /// Audio is `nil` here: the editor presents `AudioBottomSheetViewController` with `RouterDelegate.presentBottomSheet(_:config:)`.
    /// Text is `nil`: the editor presents `TextBottomSheetViewController` modally (`overFullScreen` + custom in-controller sheet panel).
    static func presentation(for item: FeatureItem) -> (route: Route, configuration: SheetConfiguration)? {
        switch item.id {
        case "audio":
            return nil
        case "text":
            return nil
        case "sticker":
            let detentId = UISheetPresentationController.Detent.Identifier("medium")
            let customDetent = UISheetPresentationController.Detent.custom(identifier: detentId) { _ in 400.resp }
            let configuration = SheetConfiguration(
                detents: [customDetent],
                selectedIdentifier: detentId,
                isDismissable: true,
                prefersScrollExpand: false,
                largestUndimmedIdentifier: detentId,
                cornerRadius: 24.resp,
                prefersGrabber: true,
                reportedHeight: .zero
            )
            return (.stickerBottomSheet, configuration)
        default:
            return nil
        }
    }
}
