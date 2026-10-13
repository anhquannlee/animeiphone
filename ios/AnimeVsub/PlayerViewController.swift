import UIKit
import AVKit

final class PlayerViewController: AVPlayerViewController {
    private let chapter: ChapterInfo
    private let episodeTitle: String
    private let animeID: String
    private var playerURL: URL?
    private var playerData: PlayerData?
    private var didLoad = false
    private let loadingLabel = UILabel()

    init(chapter: ChapterInfo, title: String, animeID: String = "") {
        self.chapter = chapter
        self.episodeTitle = title
        self.animeID = animeID
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Tải tập", style: .plain,
                                                             target: self, action: #selector(download))
        loadingLabel.text = "Đang lấy link phát…"
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        if loadingLabel.superview == nil {
            view.addSubview(loadingLabel)
            NSLayoutConstraint.activate([
                loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                loadingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
        guard !didLoad else { return }
        didLoad = true
        APIClient.shared.player(chapter: chapter) { [weak self] result in
            switch result {
            case .success(let data):
                guard let url = URL(string: data.link),
                      let scheme = url.scheme,
                      scheme == "http" || scheme == "https" else {
                    self?.showPlaybackError("Link phát không hợp lệ: \(data.link)")
                    return
                }
                self?.playerURL = url
                self?.playerData = data
                self?.loadingLabel.removeFromSuperview()
                self?.navigationItem.rightBarButtonItem?.isEnabled = true
                let asset = AVURLAsset(url: url, options: [
                    "AVURLAssetHTTPHeaderFieldsKey": data.headers ?? [
                        "Referer": APIClient.shared.baseURL.absoluteString,
                        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1"
                    ]
                ])
                let item = AVPlayerItem(asset: asset)
                NotificationCenter.default.addObserver(
                    self as Any,
                    selector: #selector(PlayerViewController.itemFailed(_:)),
                    name: .AVPlayerItemFailedToPlayToEndTime,
                    object: item
                )
                self?.player = AVPlayer(playerItem: item)
                self?.player?.play()
            case .failure(let error):
                self?.loadingLabel.text = "Không lấy được link native."
                self?.showPlaybackError("\(error)\nCó thể mở trình phát website để server tự giải mã.", url: nil)
            }
        }
    }

    @objc private func itemFailed(_ notification: Notification) {
        showPlaybackError("AVPlayer không phát được playlist hoặc segment.", url: playerURL)
    }

    private func showPlaybackError(_ message: String, url: URL? = nil) {
        let alert = UIAlertController(title: "Không thể phát video", message: message, preferredStyle: .alert)
        if let url = url {
            alert.addAction(UIAlertAction(title: "Tải về để xem", style: .default) { [weak self] _ in
                DownloadManager.shared.start(title: self?.episodeTitle ?? "AnimeVsub",
                                              id: self?.chapter.id ?? UUID().uuidString,
                                              url: url)
                self?.showDownloadStarted()
            })
        }
        alert.addAction(UIAlertAction(title: "Mở trình phát website", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.navigationController?.pushViewController(
                WebPlayerViewController(animeID: self.animeID, chapterID: self.chapter.id),
                animated: true
            )
        })
        alert.addAction(UIAlertAction(title: "Đóng", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    @objc private func download() {
        guard let url = playerURL else {
            showPlaybackError("Chưa có link phát để tải. Hãy chờ lấy link hoặc mở trình phát website.", url: nil)
            return
        }
        DownloadManager.shared.start(title: episodeTitle, id: chapter.id, url: url)
        showDownloadStarted()
    }

    private func showDownloadStarted() {
        let alert = UIAlertController(title: "Đã bắt đầu tải",
                                      message: "Mở tab Đã tải để xem tiến độ. Bạn có thể xem khi tải xong.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
