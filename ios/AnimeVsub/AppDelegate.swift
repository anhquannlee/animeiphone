import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UIApplication.shared.statusBarStyle = .lightContent
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().barTintColor = .black
        UINavigationBar.appearance().tintColor = .white
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
        UITabBar.appearance().barStyle = .black
        UITabBar.appearance().barTintColor = .black
        UITabBar.appearance().tintColor = UIColor(red: 0.88, green: 0.24, blue: 0.50, alpha: 1)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
