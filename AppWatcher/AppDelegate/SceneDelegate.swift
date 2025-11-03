import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    // Создаем экземпляр UpdateManager, который будет жить вместе со сценой
    private let updateManager = UpdateManager()
    let backgroundTaskManager = BackgroundTaskManager()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        // Создаем корневой UI
        let appRoot = AppRoot()
            .environmentObject(updateManager) // Передаем менеджер в SwiftUI
        
        let viewController = UIViewController() // Можно использовать ваш ViewController, если он нужен
        let hostingController = UIHostingController(rootView: appRoot)
        
        viewController.addChild(hostingController)
        viewController.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: viewController)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor)
        ])
        
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = viewController
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    // --- ВОТ НАШ ТРИГГЕР ---
    func sceneDidEnterBackground(_ scene: UIScene) {
            // НОВОЕ: Планируем настоящую фоновую задачу
            print("Приложение перешло в фон. Планирую фоновую проверку.")
            backgroundTaskManager.scheduleAppRefresh()
        }
}
