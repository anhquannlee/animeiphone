import UIKit
import AVKit

private final class DownloadCell: UITableViewCell {
    let posterView = AsyncImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.layer.cornerRadius = 5
        posterView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(posterView)
        NSLayoutConstraint.activate([
            posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            posterView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            posterView.widthAnchor.constraint(equalToConstant: 54),
            posterView.heightAnchor.constraint(equalToConstant: 76),
            textLabel!.leadingAnchor.constraint(equalTo: posterView.trailingAnchor, constant: 10),
            textLabel!.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            textLabel!.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class HistoryViewController: UITableViewController {
    private var records = [DownloadRecord]()
    private var groups = [(String, [DownloadRecord])]()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Đã tải"
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.register(DownloadCell.self, forCellReuseIdentifier: "DownloadCell")
        tableView.rowHeight = 96
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        NotificationCenter.default.addObserver(self, selector: #selector(reloadRecords),
                                               name: DownloadManager.didChange, object: nil)
        reloadRecords()
    }

    @objc private func reloadRecords() {
        records = DownloadManager.shared.allRecords()
        let grouped = Dictionary(grouping: records) { $0.collectionID ?? $0.id }
        groups = grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadCell", for: indexPath) as! DownloadCell
        let group = groups[indexPath.row].1
        let done = group.filter { $0.state == "downloaded" }.count
        let knownProgress = group.map(\.progress).filter { $0 >= 0 }
        let progress = knownProgress.isEmpty ? -1 :
            knownProgress.reduce(0, +) / Double(knownProgress.count)
        let title = group.first?.collectionTitle ?? group.first?.title ?? "AnimeVsub"
        let isResolving = group.contains(where: { $0.state == "Đang lấy link" })
        let hasError = group.contains(where: { $0.state.hasPrefix("error:") })
        let state = isResolving ? "Đang lấy link…" : hasError ? "Có tập lỗi" : "Đang tải"
        let progressText = progress < 0 ? "đang chuẩn bị" : "\(Int(progress * 100))%"
        cell.textLabel?.text = "\(title)\n\(done)/\(group.count) tập — \(progressText) — \(state)"
        if let image = group.first?.image, let url = URL(string: image) {
            cell.posterView.load(url: url)
        } else {
            cell.posterView.image = nil
        }
        cell.textLabel?.textColor = .white
        cell.textLabel?.numberOfLines = 2
        cell.backgroundColor = UIColor(white: 0.12, alpha: 1)
        cell.accessoryType = done > 0 ? .disclosureIndicator : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        96
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let group = groups[indexPath.row].1
        navigationController?.pushViewController(
            DownloadCollectionViewController(title: group.first?.collectionTitle ?? "Đã tải",
                                              records: group),
            animated: true
        )
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        DownloadManager.shared.remove(records: groups[indexPath.row].1)
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
        tableView.rowHeight = 64
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
