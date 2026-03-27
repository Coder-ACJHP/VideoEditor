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
}

// MARK: - RouterDelegate Protocol
// Abstracts all navigation operations behind a protocol.
// ViewControllers depend on this protocol instead of AppRouter directly,
// making them testable and decoupled from the concrete router implementation.
@MainActor
protocol RouterDelegate: AnyObject {
    func navigate(to route: Route, animated: Bool)   // Push
    func present(to route: Route, animated: Bool)    // Modal present
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
        thumbnailService: ThumbnailGenerating = LocalThumbnailService()
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
    
    func navigateToEditor(with project: EditingProject, animated: Bool) {
        let editorVC = EditorViewController(
            router: self,
            project: project,
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
                return EditorViewController(
                    router: self,
                    project: EditingProject(name: "New Project"),
                    thumbnailGenerator: thumbnailService
                )
            case .export:
                return ExportViewController(router: self)
        }
    }
}
