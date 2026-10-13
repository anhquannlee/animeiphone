import Foundation
import AVFoundation

struct DownloadRecord: Codable {
    let id: String
    let title: String
    let sourceURL: String
    var localURL: String?
    var progress: Double
    var state: String
}

final class DownloadManager: NSObject, AVAssetDownloadDelegate {
    static let shared = DownloadManager()
    static let didChange = Notification.Name("AnimeVsubDownloadsDidChange")

    private let recordsKey = "AnimeVsub.downloadRecords"
    private var tasks = [AVAssetDownloadTask: String]()
    private var records: [DownloadRecord] = []
    private lazy var session: AVAssetDownloadURLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "git.shin.animevsub.downloads")
        return AVAssetDownloadURLSession(configuration: configuration,
                                         assetDownloadDelegate: self,
                                         delegateQueue: OperationQueue.main)
    }()

    override private init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let saved = try? JSONDecoder().decode([DownloadRecord].self, from: data) {
            records = saved
        }
    }

    func allRecords() -> [DownloadRecord] {
        records
    }

    func localURL(for id: String) -> URL? {
        guard let record = records.first(where: { $0.id == id }),
              let path = record.localURL else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func start(title: String, id: String, url: URL) {
        if let existing = records.first(where: { $0.id == id }), existing.state == "downloading" {
            return
        }
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "Referer": APIClient.shared.baseURL.absoluteString,
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1"
            ]
        ])
        let task = session.makeAssetDownloadTask(asset: asset,
                                                  assetTitle: title,
                                                  assetArtworkData: nil,
                                                  options: nil)
        records.removeAll { $0.id == id }
        records.append(DownloadRecord(id: id, title: title, sourceURL: url.absoluteString,
                                      localURL: nil, progress: 0, state: "downloading"))
        tasks[task] = id
        save()
        task.resume()
        notify()
    }

    func assetDownloadURL(for record: DownloadRecord) -> URL? {
        guard let path = record.localURL else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {
        guard let id = tasks[assetDownloadTask],
              let index = records.firstIndex(where: { $0.id == id }) else { return }
        let loaded = loadedTimeRanges.reduce(0.0) {
            $0 + CMTimeGetSeconds($1.timeRangeValue.duration)
        }
        let expected = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        records[index].progress = expected > 0 ? min(loaded / expected, 1) : 0
        save()
        notify()
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let id = tasks[assetDownloadTask],
              let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].localURL = location.path
        records[index].progress = 1
        records[index].state = "downloaded"
        save()
        notify()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let downloadTask = task as? AVAssetDownloadTask,
              let id = tasks[downloadTask],
              let index = records.firstIndex(where: { $0.id == id }) else { return }
        if let error = error {
            records[index].state = "error: \(error.localizedDescription)"
            save()
            notify()
        }
        tasks.removeValue(forKey: downloadTask)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordsKey)
        }
    }

    private func notify() {
        NotificationCenter.default.post(name: DownloadManager.didChange, object: nil)
    }
}
