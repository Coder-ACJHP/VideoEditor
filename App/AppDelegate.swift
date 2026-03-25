//
//  AppDelegate.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 25.03.2026.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

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
