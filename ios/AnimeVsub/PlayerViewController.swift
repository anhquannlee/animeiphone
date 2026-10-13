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
                self?.player = AVPlayer(url: url)
                self?.player?.play()
            case .failure:
                self?.dismiss(animated: true)
            }
        }
    }
}
