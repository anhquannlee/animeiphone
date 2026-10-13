import UIKit

final class DetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let anime: AnimeCard
    private let imageView = AsyncImageView()
    private let textLabel = UILabel()
    private let episodesLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var episodes = [ChapterInfo]()

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
        textLabel.font = UIFont.systemFont(ofSize: 13)
        textLabel.text = "\(anime.name)\n\nChất lượng: \(anime.quality ?? "Đang cập nhật")"
        episodesLabel.text = "Đang tải danh sách tập…"
        episodesLabel.textColor = UIColor(white: 0.8, alpha: 1)
        episodesLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        tableView.backgroundColor = UIColor(white: 0.07, alpha: 1)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "EpisodeCell")
        let playButton = UIButton(type: .system)
        playButton.setTitle("  Xem tập mới nhất  ", for: .normal)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = UIColor(red: 0.82, green: 0.18, blue: 0.45, alpha: 1)
        playButton.layer.cornerRadius = 7
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        [imageView, textLabel, playButton, episodesLabel, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            imageView.widthAnchor.constraint(equalToConstant: 112),
            imageView.heightAnchor.constraint(equalToConstant: 168),
            textLabel.topAnchor.constraint(equalTo: imageView.topAnchor),
            textLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 16),
            textLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            playButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            playButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            playButton.heightAnchor.constraint(equalToConstant: 38),
            episodesLabel.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 16),
            episodesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            episodesLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tableView.topAnchor.constraint(equalTo: episodesLabel.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        if let url = URL(string: anime.image) { imageView.load(url: url) }
        loadEpisodes()
    }

    @objc private func play() {
        guard let episode = episodes.last ?? anime.lastEpisode else { return }
        navigationController?.pushViewController(
            PlayerViewController(chapter: episode, title: anime.name, animeID: anime.animeId),
            animated: true
        )
    }

    private func loadEpisodes() {
        APIClient.shared.episodes(animeID: anime.animeId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let episodes):
                self.episodes = episodes
                self.episodesLabel.text = "Danh sách tập (\(episodes.count))"
                self.tableView.reloadData()
            case .failure:
                self.episodesLabel.text = "Chưa lấy được danh sách tập. Hãy thử lại sau."
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        episodes.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EpisodeCell", for: indexPath)
        cell.textLabel?.text = episodes[indexPath.row].name
        cell.textLabel?.textColor = .white
        cell.backgroundColor = UIColor(white: 0.12, alpha: 1)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let episode = episodes[indexPath.row]
        navigationController?.pushViewController(
            PlayerViewController(chapter: episode,
                                 title: "\(anime.name) - \(episode.name)",
                                 animeID: anime.animeId),
            animated: true
        )
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
