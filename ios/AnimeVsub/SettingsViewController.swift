import UIKit

final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case server
        case playback
        case data
        case about

        var title: String {
            switch self {
            case .server: return "MÁY CHỦ NGUỒN (SOURCE)"
            case .playback: return "TRÌNH PHÁT"
            case .data: return "DỮ LIỆU & LƯU TRỮ"
            case .about: return "THÔNG TIN ỨNG DỤNG"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cài đặt"
        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.separatorColor = UIColor(white: 0.2, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingCell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor(red: 0.88, green: 0.24, blue: 0.50, alpha: 1)
            header.textLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .server: return 2
        case .playback: return 1
        case .data: return 2
        case .about: return 3
        case .none: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "SettingCell")
        cell.backgroundColor = UIColor(white: 0.12, alpha: 1)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor(white: 0.65, alpha: 1)

        switch Section(rawValue: indexPath.section) {
        case .server:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Tên miền hiện tại"
                cell.detailTextLabel?.text = APIClient.shared.baseURL.host ?? APIClient.shared.baseURL.absoluteString
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Xác minh / Kết nối website"
                cell.detailTextLabel?.text = "Cloudflare Check"
                cell.accessoryType = .disclosureIndicator
            }
        case .playback:
            cell.textLabel?.text = "Chế độ phát mặc định"
            cell.detailTextLabel?.text = "AVPlayer Native (HLS)"
            cell.accessoryType = .none
        case .data:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Xoá lịch sử xem"
                cell.detailTextLabel?.text = "\(WatchHistoryManager.shared.allHistory().count) phim"
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Xoá danh sách đã tải"
                cell.detailTextLabel?.text = "\(DownloadManager.shared.allRecords().count) tập"
                cell.accessoryType = .disclosureIndicator
            }
        case .about:
            if indexPath.row == 0 {
                cell.textLabel?.text = "Phiên bản"
                cell.detailTextLabel?.text = "1.0.0 (Build 2026)"
                cell.accessoryType = .none
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Tương thích"
                cell.detailTextLabel?.text = "iOS 10.0+ (iPhone 6 / 6s trở lên)"
                cell.accessoryType = .none
            } else {
                cell.textLabel?.text = "Nhà phát triển"
                cell.detailTextLabel?.text = "AnimeVsub Team"
                cell.accessoryType = .none
            }
        case .none:
            break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section) {
        case .server:
            if indexPath.row == 0 {
                promptChangeDomain()
            } else {
                openSiteBootstrap()
            }
        case .data:
            if indexPath.row == 0 {
                confirmClearWatchHistory()
            } else {
                confirmClearDownloads()
            }
        default:
            break
        }
    }

    private func promptChangeDomain() {
        let alert = UIAlertController(
            title: "Đổi tên miền nguồn",
            message: "Nhập tên miền website (mặc định: animevietsub.xyz). Ứng dụng sẽ tự động chuyển đổi sang mirror mới nhất.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.text = APIClient.shared.baseURL.absoluteString
            field.keyboardType = .URL
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Lưu & Kết nối", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let text = alert?.textFields?.first?.text,
                  APIClient.shared.setBaseURL(text) else {
                self?.showAlert(title: "Lỗi", message: "Tên miền không hợp lệ.")
                return
            }
            self.tableView.reloadData()
            self.openSiteBootstrap()
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func openSiteBootstrap() {
        let bootstrap = SiteBootstrapViewController(url: APIClient.shared.baseURL) { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.tableView.reloadData()
            }
        }
        present(UINavigationController(rootViewController: bootstrap), animated: true)
    }

    private func confirmClearWatchHistory() {
        let alert = UIAlertController(
            title: "Xoá lịch sử xem?",
            message: "Toàn bộ lịch sử các tập phim đã xem sẽ được xoá khỏi máy.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Xoá", style: .destructive) { [weak self] _ in
            WatchHistoryManager.shared.clearAll()
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func confirmClearDownloads() {
        let alert = UIAlertController(
            title: "Xoá tất cả video đã tải?",
            message: "Các tệp video đã tải về máy sẽ được giải phóng dung lượng.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Xoá tất cả", style: .destructive) { [weak self] _ in
            let all = DownloadManager.shared.allRecords()
            DownloadManager.shared.remove(records: all)
            self?.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
        present(alert, animated: true)
    }
}
