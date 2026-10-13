import UIKit
import AVKit

final class HistoryViewController: UITableViewController {
    private var records = [DownloadRecord]()
    private var groups = [(String, [DownloadRecord])]()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Đã tải"
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DownloadCell")
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadCell", for: indexPath)
        let group = groups[indexPath.row].1
        let done = group.filter { $0.state == "downloaded" }.count
        let progress = group.reduce(0) { $0 + $1.progress } / Double(max(group.count, 1))
        cell.textLabel?.text = "\(group.first?.title ?? "AnimeVsub")\n\(done)/\(group.count) tập — \(Int(progress * 100))%"
        cell.textLabel?.textColor = .white
        cell.textLabel?.numberOfLines = 2
        cell.backgroundColor = UIColor(white: 0.12, alpha: 1)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let record = groups[indexPath.row].1.first(where: { $0.state == "downloaded" })
        guard let record = record else { return }
        guard let url = DownloadManager.shared.assetDownloadURL(for: record) else { return }
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        navigationController?.pushViewController(controller, animated: true)
        controller.player?.play()
        tableView.deselectRow(at: indexPath, animated: true)
    }

}
