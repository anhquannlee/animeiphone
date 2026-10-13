import UIKit

final class AnimeCardCell: UICollectionViewCell {
    static let reuseIdentifier = "AnimeCardCell"
    let posterView = AsyncImageView()
    let titleLabel = UILabel()
    let episodeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        posterView.clipsToBounds = true
        posterView.layer.cornerRadius = 7
        posterView.contentMode = .scaleAspectFill
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.numberOfLines = 2
        titleLabel.textColor = .white
        episodeLabel.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        episodeLabel.textColor = .white
        episodeLabel.backgroundColor = UIColor(red: 0.82, green: 0.18, blue: 0.45, alpha: 0.9)
        episodeLabel.layer.cornerRadius = 4
        episodeLabel.clipsToBounds = true

        [posterView, titleLabel, episodeLabel].forEach { contentView.addSubview($0) }
        posterView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        episodeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            posterView.topAnchor.constraint(equalTo: contentView.topAnchor),
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            posterView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            posterView.heightAnchor.constraint(equalTo: posterView.widthAnchor, multiplier: 1.5),
            titleLabel.topAnchor.constraint(equalTo: posterView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            episodeLabel.leadingAnchor.constraint(equalTo: posterView.leadingAnchor, constant: 5),
            episodeLabel.bottomAnchor.constraint(equalTo: posterView.bottomAnchor, constant: -5)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(anime: AnimeCard) {
        titleLabel.text = anime.name
        episodeLabel.text = anime.lastEpisode.map { "  \($0.name)  " }
        episodeLabel.isHidden = anime.lastEpisode == nil
        if let url = URL(string: anime.image) { posterView.load(url: url) }
    }
}
