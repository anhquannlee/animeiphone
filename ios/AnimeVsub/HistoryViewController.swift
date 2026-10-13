import UIKit
import AVKit

final class HistoryViewController: UITableViewController {
    private var records = [DownloadRecord]()

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
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        records.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadCell", for: indexPath)
        let record = records[indexPath.row]
        let percent = Int(record.progress * 100)
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

    private func status(_ record: DownloadRecord, percent: Int) -> String {
        if record.state == "downloaded" { return "Đã tải — chạm để xem" }
        if record.state == "downloading" { return "Đang tải \(percent)%" }
        return record.state
    }
}
