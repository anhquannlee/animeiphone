import UIKit

class HomeViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var items = [AnimeCard]()
    let collectionView: UICollectionView
    private let refresh = UIRefreshControl()

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 16
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AnimeVsub"
        view.backgroundColor = .black
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.register(AnimeCardCell.self, forCellWithReuseIdentifier: AnimeCardCell.reuseIdentifier)
        collectionView.refreshControl = refresh
        refresh.addTarget(self, action: #selector(load), for: .valueChanged)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        load()
    }

    @objc private func load() {
        APIClient.shared.home { [weak self] result in
            guard let self = self else { return }
            self.refresh.endRefreshing()
            switch result {
            case .success(let data):
                self.items = data.lastUpdate + data.thisSeason + data.hotUpdate
                self.collectionView.reloadData()
            case .failure(let error):
                self.presentError(error)
            }
        }
    }

    func display(items: [AnimeCard]) {
        self.items = items
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AnimeCardCell.reuseIdentifier, for: indexPath) as! AnimeCardCell
        cell.configure(anime: items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        navigationController?.pushViewController(DetailViewController(anime: items[indexPath.item]), animated: true)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let columns: CGFloat = traitCollection.horizontalSizeClass == .regular ? 5 : 3
        let width = floor((collectionView.bounds.width - (columns - 1) * 10) / columns)
        return CGSize(width: width, height: width * 1.5 + 42)
    }

    private func presentError(_ error: APIError) {
        let alert = UIAlertController(title: "Không thể tải dữ liệu", message: String(describing: error), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}

extension HomeViewController: UICollectionViewDelegateFlowLayout {}
