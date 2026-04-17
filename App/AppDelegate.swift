//
// AppDelegate
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import UIKit
import CoreData

/// Entry point for the process (`@main`). Owns the Core Data stack; UI flows are driven by `SceneDelegate` and scene-based lifecycle.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Hook for one-time process setup (e.g. analytics, remote config). Scene-specific UI setup belongs in SceneDelegate.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Tells the system which storyboard / delegate class to use for this scene. Name must match an entry in Info.plist under Application Scene Manifest.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called after the user removes a window/scene from the app switcher. Tear down resources tied to those sessions only if you created any outside the scene itself.
    }

    // MARK: - Core Data stack

    /// Lazily loads the persistent store on first access so cold launch stays fast until something touches the database.
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "VideoEditor")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Replace this with proper production-grade error handling.
                // fatalError is intentional here to surface misconfigured
                // data model issues during development.
                fatalError("Unresolved Core Data error: \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    // MARK: - Core Data Saving Support

    /// Persists pending changes on the main queue context. Call from lifecycle hooks (e.g. scene background) or after batched edits.
    func saveContext() {
        let context = persistentContainer.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved Core Data save error: \(nserror), \(nserror.userInfo)")
        }
    }
}
