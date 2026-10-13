import UIKit

final class DetailViewController: UIViewController {
    private let anime: AnimeCard
    private let imageView = AsyncImageView()
    private let textLabel = UILabel()

    init(anime: AnimeCard) {
        self.anime = anime
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = anime.name
        view.backgroundColor = .black
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        textLabel.textColor = .white
        textLabel.numberOfLines = 0
        textLabel.font = UIFont.systemFont(ofSize: 15)
        textLabel.text = "\(anime.name)\n\nChất lượng: \(anime.quality ?? "Đang cập nhật")"
        let playButton = UIButton(type: .system)
        playButton.setTitle("  Xem tập mới nhất  ", for: .normal)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = UIColor(red: 0.82, green: 0.18, blue: 0.45, alpha: 1)
        playButton.layer.cornerRadius = 7
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        [imageView, textLabel, playButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.widthAnchor.constraint(equalToConstant: 130),
            imageView.heightAnchor.constraint(equalToConstant: 195),
            textLabel.topAnchor.constraint(equalTo: imageView.topAnchor),
            textLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            playButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        if let url = URL(string: anime.image) { imageView.load(url: url) }
    }

    @objc private func play() {
        guard let episode = anime.lastEpisode else { return }
        navigationController?.pushViewController(PlayerViewController(chapterID: episode.id, title: anime.name), animated: true)
    }
}
