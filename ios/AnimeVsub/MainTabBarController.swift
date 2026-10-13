import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        tabBar.barStyle = .black
        tabBar.barTintColor = .black
        tabBar.tintColor = UIColor(red: 0.88, green: 0.24, blue: 0.50, alpha: 1)

        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(tabBarSystemItem: .featured, tag: 0)
        home.tabBarItem.title = "Trang chủ"

        let search = UINavigationController(rootViewController: SearchViewController())
        search.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 1)
        search.tabBarItem.title = "Tìm kiếm"

        let history = UINavigationController(rootViewController: HistoryViewController())
        history.tabBarItem = UITabBarItem(tabBarSystemItem: .history, tag: 2)
        history.tabBarItem.title = "Lịch sử & Tải"

        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "Cài đặt", image: settingsIcon(), tag: 3)

        viewControllers = [home, search, history, settings]
    }

    private func settingsIcon() -> UIImage? {
        // Draw a simple, clean gear/settings icon for iOS 10+ without SF Symbols dependency
        let size = CGSize(width: 24, height: 24)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setFillColor(UIColor.white.cgColor)
        let rect = CGRect(x: 2, y: 2, width: 20, height: 20)
        ctx.strokeEllipse(in: rect)

        let innerRect = CGRect(x: 7, y: 7, width: 10, height: 10)
        ctx.fillEllipse(in: innerRect)

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}
