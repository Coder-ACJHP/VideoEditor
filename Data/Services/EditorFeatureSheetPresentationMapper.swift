//
//  EditorFeatureSheetPresentationMapper.swift
//  VideoEditor
//
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

    /// Returns route and sheet config for editor feature bottom sheets, or `nil` for unknown items.
    /// Audio is `nil` here: the editor presents `AudioBottomSheetViewController` with `RouterDelegate.presentBottomSheet(_:config:)`.
    static func presentation(for item: FeatureItem) -> (route: Route, configuration: SheetConfiguration)? {
        let textSheetConfiguration = SheetConfiguration(
            detents: [.large()],
            selectedIdentifier: .large,
            isDismissable: true,
            prefersScrollExpand: false,
            largestUndimmedIdentifier: .large,
            cornerRadius: 24.resp,
            prefersGrabber: true,
            reportedHeight: .zero
        )

        switch item.id {
        case "audio":
            return nil
        case "text":
            return (.textBottomSheet, textSheetConfiguration)
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
