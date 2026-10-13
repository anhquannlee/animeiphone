import UIKit

final class SearchViewController: HomeViewController, UISearchBarDelegate {
    private let searchBar = UISearchBar()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tìm kiếm"
        searchBar.placeholder = "Tên anime"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
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
