import UIKit

final class SearchViewController: HomeViewController, UISearchBarDelegate {
    private let searchBar = UISearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tìm kiếm"
        searchBar.placeholder = "Tên anime"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = .white
        searchBar.barTintColor = UIColor(white: 0.12, alpha: 1)
        searchBar.backgroundColor = UIColor(white: 0.12, alpha: 1)
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = .white
            textField.tintColor = .white
            textField.backgroundColor = UIColor(white: 0.18, alpha: 1)
            textField.attributedPlaceholder = NSAttributedString(
                string: "Tên anime",
                attributes: [.foregroundColor: UIColor(white: 0.72, alpha: 1)]
            )
        }
        navigationItem.titleView = searchBar
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let keyword = searchBar.text, !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchBar.resignFirstResponder()
        // Search endpoint integration is kept in APIClient; the Home screen remains the low-memory grid.
        APIClient.shared.search(keyword: keyword) { [weak self] result in
            switch result {
            case .success(let page):
                self?.display(items: page.items)
            case .failure(let error):
                let alert = UIAlertController(title: "Tìm kiếm thất bại", message: String(describing: error), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Đóng", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
}
