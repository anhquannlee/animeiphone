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
        let search = UINavigationController(rootViewController: SearchViewController())
        search.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 1)
        let history = UIViewController()
        history.view.backgroundColor = .black
        history.tabBarItem = UITabBarItem(tabBarSystemItem: .history, tag: 2)
        viewControllers = [home, search, history]
    }
}
