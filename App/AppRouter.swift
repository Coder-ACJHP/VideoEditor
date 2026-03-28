//
//  AppRouter.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 25.03.2026.
//

import Foundation
import UIKit

enum Route: String, CaseIterable {
    case landing
    case editor
    case export
    case audioBottomSheet
    case stickerBottomSheet
    case textBottomSheet
}

// MARK: - RouterDelegate Protocol
// Abstracts all navigation operations behind a protocol.
// ViewControllers depend on this protocol instead of AppRouter directly,
// making them testable and decoupled from the concrete router implementation.
@MainActor
protocol RouterDelegate: AnyObject {
    func navigate(to route: Route, animated: Bool)   // Push
    func present(to route: Route, animated: Bool)    // Modal present
    func presentBottomSheet(
        to route: Route,
        config: SheetConfiguration,
        animated: Bool
    )    // BottomSheet
    /// Presents a pre-built controller as a sheet (e.g. editor-owned `AudioBottomSheetViewController` with callbacks).
    func presentBottomSheet(
        _ viewController: UIViewController,
        config: SheetConfiguration,
        animated: Bool
    )
    func pop(animated: Bool)
    func dismiss(animated: Bool)
    func makeViewController(baseRoute route: Route) -> UIViewController  // Factory
    /// Pushes the editor pre-loaded with a specific project. Prefer this over
    /// `navigate(to: .editor)` because it properly injects the domain model.
    func navigateToEditor(with project: EditingProject, animated: Bool)
}

@MainActor
class AppRouter: RouterDelegate {
    
    private let controller: UINavigationController
    private let thumbnailService: ThumbnailGenerating
    
    init(
        controller: UINavigationController,
        thumbnailService: ThumbnailGenerating
    ) {
        self.controller = controller
        self.thumbnailService = thumbnailService
    }
    
    func navigate(to route: Route, animated: Bool) {
        let destinationVC = makeViewController(baseRoute: route)
        controller.pushViewController(destinationVC, animated: animated)
    }
    
    func pop(animated: Bool) {
        controller.popViewController(animated: animated)
    }
    
    func present(to route: Route, animated: Bool) {
        let destinationVC = makeViewController(baseRoute: route)
        // Wraps in a new NavigationController so the modal has its own navigation stack
        let nav = UINavigationController(rootViewController: destinationVC)
        controller.present(nav, animated: animated)
    }
    
    func dismiss(animated: Bool) {
        controller.dismiss(animated: animated)
    }
    
    func presentBottomSheet(to route: Route, config configuration: SheetConfiguration, animated: Bool) {
        let bottomSheet = makeViewController(baseRoute: route)        
        bottomSheet.modalPresentationStyle = .pageSheet
        bottomSheet.isModalInPresentation = !configuration.isDismissable

        if let sheet = bottomSheet.sheetPresentationController {
            sheet.detents = configuration.detents
            sheet.selectedDetentIdentifier = configuration.selectedIdentifier
            sheet.prefersGrabberVisible = configuration.prefersGrabber
            sheet.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollExpand
            sheet.preferredCornerRadius = configuration.cornerRadius

            if let largestUndimmed = configuration.largestUndimmedIdentifier {
                sheet.largestUndimmedDetentIdentifier = largestUndimmed
            }
        }

        controller.present(bottomSheet, animated: animated, completion: nil)
    }

    func presentBottomSheet(_ viewController: UIViewController, config configuration: SheetConfiguration, animated: Bool) {
        viewController.modalPresentationStyle = .pageSheet
        viewController.isModalInPresentation = !configuration.isDismissable

        if let sheet = viewController.sheetPresentationController {
            sheet.detents = configuration.detents
            sheet.selectedDetentIdentifier = configuration.selectedIdentifier
            sheet.prefersGrabberVisible = configuration.prefersGrabber
            sheet.prefersScrollingExpandsWhenScrolledToEdge = configuration.prefersScrollExpand
            sheet.preferredCornerRadius = configuration.cornerRadius

            if let largestUndimmed = configuration.largestUndimmedIdentifier {
                sheet.largestUndimmedDetentIdentifier = largestUndimmed
            }
        }

        controller.present(viewController, animated: animated, completion: nil)
    }

    func navigateToEditor(with project: EditingProject, animated: Bool) {
        let viewModel = EditorViewModel(project: project)
        let editorVC = EditorViewController(
            router: self,
            viewModel: viewModel,
            thumbnailGenerator: thumbnailService
        )
        controller.pushViewController(editorVC, animated: animated)
    }

    // MARK: ViewController Factory
    // Single place responsible for creating ViewControllers and injecting the router.
    // Adding a new screen only requires a new Route case and an entry here.
    func makeViewController(baseRoute route: Route) -> UIViewController {
        switch route {
            case .landing:
                return LandingViewController(router: self, thumbnailService: thumbnailService)
            case .editor:
                // Fallback with an empty project; prefer navigateToEditor(with:animated:) for real use.
                let viewModel = EditorViewModel(project: EditingProject(name: "New Project"))
                return EditorViewController(
                    router: self,
                    viewModel: viewModel,
                    thumbnailGenerator: thumbnailService
                )
            case .export:
                return ExportViewController(router: self)
            case .audioBottomSheet:
                return AudioBottomSheetViewController(router: self)
            case .stickerBottomSheet:
                return StickerBottomSheetViewController(router: self)
            case .textBottomSheet:
                return TextBottomSheetViewController(router: self)
        }
    }
}
