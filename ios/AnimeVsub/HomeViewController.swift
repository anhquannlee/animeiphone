import UIKit

class HomeViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var items = [AnimeCard]()
    let collectionView: UICollectionView
    private let refresh = UIRefreshControl()
    private let emptyLabel = UILabel()

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 10
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "AnimeVsub"
        view.backgroundColor = UIColor(white: 0.07, alpha: 1)
        collectionView.backgroundColor = UIColor(white: 0.07, alpha: 1)
        emptyLabel.text = "Đang tải dữ liệu…"
        emptyLabel.textColor = UIColor(white: 0.78, alpha: 1)
        emptyLabel.font = UIFont.systemFont(ofSize: 15)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.register(AnimeCardCell.self, forCellWithReuseIdentifier: AnimeCardCell.reuseIdentifier)
        collectionView.refreshControl = refresh
        refresh.addTarget(self, action: #selector(load), for: .valueChanged)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
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
                self.emptyLabel.isHidden = !self.items.isEmpty
                self.emptyLabel.text = "Chưa có anime để hiển thị."
            case .failure(let error):
                self.emptyLabel.isHidden = false
                self.emptyLabel.text = "Không tải được dữ liệu.\nKéo xuống để thử lại."
                self.presentError(error)
            }
        }
    }

    func display(items: [AnimeCard]) {
        self.items = items
        collectionView.reloadData()
        emptyLabel.isHidden = !items.isEmpty
        emptyLabel.text = "Không tìm thấy anime."
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
        let width = floor((collectionView.bounds.width - (columns - 1) * 6) / columns)
        return CGSize(width: width, height: width * 1.5 + 36)
    }

    private func presentError(_ error: APIError) {
        let alert = UIAlertController(
            title: "Không thể tải dữ liệu",
            message: "\(error)\nBạn có thể nhập domain khác hoặc mở website để xử lý Cloudflare trước.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Thử lại", style: .default) { [weak self] _ in
            self?.load()
        })
        alert.addAction(UIAlertAction(title: "Nhập link website", style: .default) { [weak self] _ in
            self?.requestSiteURL()
        })
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        present(alert, animated: true)
    }

    private func requestSiteURL() {
        let alert = UIAlertController(title: "Nhập link website", message: "Ví dụ: animevietsub.pl", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = APIClient.shared.baseURL.absoluteString
            field.keyboardType = .URL
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Mở website", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let value = alert?.textFields?.first?.text,
                  APIClient.shared.setBaseURL(value) else {
                self?.showInvalidURL()
                return
            }
            let bootstrap = SiteBootstrapViewController(url: APIClient.shared.baseURL) { [weak self] _ in
                self?.dismiss(animated: true) { self?.load() }
            }
            self.present(UINavigationController(rootViewController: bootstrap), animated: true)
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func showInvalidURL() {
        let alert = UIAlertController(title: "Link không hợp lệ", message: "Hãy nhập tên miền hoặc URL bắt đầu bằng http:// hoặc https://.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}

extension HomeViewController: UICollectionViewDelegateFlowLayout {}
