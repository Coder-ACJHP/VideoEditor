//
//  SheetConfiguration.swift
//  VideoEditor
//
//  UIKit sheet presentation options. Lives in Presentation (not Domain/Shared)
//  because it wraps UISheetPresentationController types.
//

import UIKit

struct SheetConfiguration {
    let detents: [UISheetPresentationController.Detent]
    let selectedIdentifier: UISheetPresentationController.Detent.Identifier?
    let isDismissable: Bool
    let prefersScrollExpand: Bool
    let largestUndimmedIdentifier: UISheetPresentationController.Detent.Identifier?
    let cornerRadius: CGFloat
    let prefersGrabber: Bool
    let reportedHeight: CGFloat
}

// MARK: - Factory Methods

extension SheetConfiguration {

    /// Single custom-height detent (most bottom sheets).
    static func custom(
        height: CGFloat,
        identifier: String = "custom",
        isDismissable: Bool = false,
        prefersScrollExpand: Bool = false
    ) -> SheetConfiguration {
        let detentId = UISheetPresentationController.Detent.Identifier(identifier)
        let detent = UISheetPresentationController.Detent.custom(identifier: detentId) { _ in height }
        return SheetConfiguration(
            detents: [detent],
            selectedIdentifier: detentId,
            isDismissable: isDismissable,
            prefersScrollExpand: prefersScrollExpand,
            largestUndimmedIdentifier: nil,
            cornerRadius: 24.resp,
            prefersGrabber: false,
            reportedHeight: height
        )
    }

    /// Full-height `.large()` detent (settings-style sheets).
    static func large(isDismissable: Bool = false) -> SheetConfiguration {
        SheetConfiguration(
            detents: [.large()],
            selectedIdentifier: .large,
            isDismissable: isDismissable,
            prefersScrollExpand: false,
            largestUndimmedIdentifier: nil,
            cornerRadius: 24.resp,
            prefersGrabber: false,
            reportedHeight: 750.resp
        )
    }

    /// Starts at a custom height and expands through `.medium()` and `.large()`.
    static func expandable(
        initialHeight: CGFloat,
        identifier: String = "small",
        isDismissable: Bool = false
    ) -> SheetConfiguration {
        let detentId = UISheetPresentationController.Detent.Identifier(identifier)
        let customDetent = UISheetPresentationController.Detent.custom(identifier: detentId) { _ in initialHeight }
        return SheetConfiguration(
            detents: [customDetent, .medium(), .large()],
            selectedIdentifier: detentId,
            isDismissable: isDismissable,
            prefersScrollExpand: true,
            largestUndimmedIdentifier: .large,
            cornerRadius: 24.resp,
            prefersGrabber: false,
            reportedHeight: initialHeight
        )
    }
}
