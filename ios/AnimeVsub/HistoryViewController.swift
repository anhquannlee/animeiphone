import UIKit
import AVKit

private final class HistoryCell: UITableViewCell {
    let posterView = AsyncImageView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 0.12, alpha: 1)
        selectionStyle = .default

        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.layer.cornerRadius = 5
        posterView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.textColor = UIColor(red: 0.88, green: 0.24, blue: 0.50, alpha: 1)
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.textColor = UIColor(white: 0.65, alpha: 1)
        timeLabel.font = UIFont.systemFont(ofSize: 11)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(posterView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            posterView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            posterView.widthAnchor.constraint(equalToConstant: 54),
            posterView.heightAnchor.constraint(equalToConstant: 76),

            titleLabel.topAnchor.constraint(equalTo: posterView.topAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            timeLabel.bottomAnchor.constraint(equalTo: posterView.bottomAnchor, constant: -4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class HistoryViewController: UITableViewController {
    private enum Segment: Int {
        case watchHistory = 0
        case downloads = 1
    }

    private let segmentedControl = UISegmentedControl(items: ["Lịch sử xem", "Đã tải về"])
    private var watchHistory = [WatchHistoryItem]()
    private var downloadRecords = [DownloadRecord]()
    private var downloadGroups = [(String, [DownloadRecord])]()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lịch sử & Tải về"
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.register(HistoryCell.self, forCellReuseIdentifier: "HistoryCell")
        tableView.rowHeight = 96
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.tintColor = UIColor(red: 0.88, green: 0.24, blue: 0.50, alpha: 1)
        navigationItem.titleView = segmentedControl

        NotificationCenter.default.addObserver(self, selector: #selector(reloadData),
                                               name: DownloadManager.didChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData),
                                               name: WatchHistoryManager.didChange, object: nil)
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    @objc private func segmentChanged() {
        tableView.reloadData()
    }

    @objc private func reloadData() {
        watchHistory = WatchHistoryManager.shared.allHistory()
        downloadRecords = DownloadManager.shared.allRecords()
        let grouped = Dictionary(grouping: downloadRecords) { $0.collectionID ?? $0.id }
        downloadGroups = grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == Segment.watchHistory.rawValue {
            return watchHistory.count
        } else {
            return downloadGroups.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! HistoryCell

        if segmentedControl.selectedSegmentIndex == Segment.watchHistory.rawValue {
            let item = watchHistory[indexPath.row]
            cell.titleLabel.text = item.animeTitle
            cell.subtitleLabel.text = "Tập: \(item.episodeTitle) • Tiến độ: \(item.progressPercent)%"
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm dd/MM/yyyy"
            cell.timeLabel.text = "Xem lúc: \(formatter.string(from: item.watchedAt))"

            if let img = item.image, let url = URL(string: img) {
                cell.posterView.load(url: url)
            } else {
                cell.posterView.image = nil
            }
            cell.accessoryType = .disclosureIndicator
        } else {
            let group = downloadGroups[indexPath.row].1
            let done = group.filter { $0.state == "downloaded" }.count
            let knownProgress = group.map(\.progress).filter { $0 >= 0 }
            let progress = knownProgress.isEmpty ? -1 :
                knownProgress.reduce(0, +) / Double(knownProgress.count)
            let title = group.first?.collectionTitle ?? group.first?.title ?? "AnimeVsub"
            let isResolving = group.contains(where: { $0.state == "Đang lấy link" })
            let hasError = group.contains(where: { $0.state.hasPrefix("error:") })
            let state = isResolving ? "Đang lấy link…" : hasError ? "Có tập lỗi" : "Đang tải"
            let progressText = progress < 0 ? "đang chuẩn bị" : "\(Int(progress * 100))%"

            cell.titleLabel.text = title
            cell.subtitleLabel.text = "\(done)/\(group.count) tập — \(progressText) — \(state)"
            cell.timeLabel.text = done == group.count ? "Đã tải xong toàn bộ" : "Chạm để xem chi tiết tập"

            if let image = group.first?.image, let url = URL(string: image) {
                cell.posterView.load(url: url)
            } else {
                cell.posterView.image = nil
            }
            cell.accessoryType = done > 0 ? .disclosureIndicator : .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        96
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if segmentedControl.selectedSegmentIndex == Segment.watchHistory.rawValue {
            let item = watchHistory[indexPath.row]
            let card = AnimeCard(
                animeId: item.animeId,
                image: item.image ?? "",
                name: item.animeTitle,
                lastEpisode: nil,
                rate: 0,
                views: nil,
                quality: nil,
                process: nil,
                year: nil
            )
            navigationController?.pushViewController(DetailViewController(anime: card), animated: true)
        } else {
            let group = downloadGroups[indexPath.row].1
            navigationController?.pushViewController(
                DownloadCollectionViewController(title: group.first?.collectionTitle ?? "Đã tải",
                                                  records: group),
                animated: true
            )
        }
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }

        if segmentedControl.selectedSegmentIndex == Segment.watchHistory.rawValue {
            let item = watchHistory[indexPath.row]
            WatchHistoryManager.shared.remove(animeId: item.animeId)
            watchHistory.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        } else {
            DownloadManager.shared.remove(records: downloadGroups[indexPath.row].1)
            downloadGroups.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    override func tableView(_ tableView: UITableView,
                            titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        "Xoá"
    }
}

private final class DownloadCollectionViewController: UITableViewController {
    private let collectionTitle: String
    private var records: [DownloadRecord]

    init(title: String, records: [DownloadRecord]) {
        collectionTitle = title
        self.records = records
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = collectionTitle
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "EpisodeDownloadCell")
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: DownloadManager.didChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func refresh() {
        let ids = Set(records.map { $0.id })
        records = DownloadManager.shared.allRecords().filter { ids.contains($0.id) }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EpisodeDownloadCell", for: indexPath)
        let record = records[indexPath.row]
        let percent = record.progress < 0 ? "đang chuẩn bị" : "\(Int(record.progress * 100))%"
        cell.textLabel?.text = "\(record.title)\n\(status(record, percent: percent))"
        cell.textLabel?.textColor = .white
        cell.textLabel?.numberOfLines = 2
        cell.backgroundColor = UIColor(white: 0.12, alpha: 1)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let record = records[indexPath.row]
        guard let url = DownloadManager.shared.assetDownloadURL(for: record) else { return }
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        navigationController?.pushViewController(controller, animated: true)
        controller.player?.play()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        DownloadManager.shared.remove(records: [records[indexPath.row]])
    }

    private func status(_ record: DownloadRecord, percent: String) -> String {
        if record.state == "downloaded" { return "Đã tải — chạm để xem" }
        if record.state == "Đang lấy link" { return "Đang lấy link…" }
        if record.state == "downloading" { return "Đang tải \(percent)" }
        return record.state
    }
}
