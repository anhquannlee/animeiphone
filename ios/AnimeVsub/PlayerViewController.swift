import UIKit
import AVKit

final class PlayerViewController: AVPlayerViewController {
    private let chapter: ChapterInfo
    private let episodeTitle: String

    init(chapter: ChapterInfo, title: String) {
        self.chapter = chapter
        self.episodeTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        APIClient.shared.player(chapter: chapter) { [weak self] result in
            switch result {
            case .success(let data):
                guard let url = URL(string: data.link) else { return }
                let asset = AVURLAsset(url: url, options: [
                    "AVURLAssetHTTPHeaderFieldsKey": data.headers ?? [
                        "Referer": APIClient.shared.baseURL.absoluteString,
                        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1"
                    ]
                ])
                self?.player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                self?.player?.play()
            case .failure(let error):
                let alert = UIAlertController(
                    title: "Không thể phát video",
                    message: "\(error)\nMáy chủ chưa trả về link m3u8 hợp lệ hoặc đang chặn truy cập.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Đóng", style: .default) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                self?.present(alert, animated: true)
            }
        }
    }
}
