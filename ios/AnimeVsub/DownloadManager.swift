import Foundation
import AVFoundation

struct DownloadRecord: Codable {
    let id: String
    let title: String
    let sourceURL: String
    let collectionID: String?
    let collectionTitle: String?
    let image: String?
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
        session.getAllTasks { [weak self] tasks in
            guard let self = self else { return }
            for task in tasks {
                guard let downloadTask = task as? AVAssetDownloadTask,
                      let id = downloadTask.taskDescription,
                      self.records.contains(where: { $0.id == id }) else { continue }
                self.tasks[downloadTask] = id
                if let index = self.records.firstIndex(where: { $0.id == id }),
                   self.records[index].state != "downloaded" {
                    self.records[index].state = "downloading"
                }
            }
            self.save()
            self.notify()
        }
    }

    func allRecords() -> [DownloadRecord] {
        records
    }

    func remove(records recordsToRemove: [DownloadRecord]) {
        let ids = Set(recordsToRemove.map { $0.id })
        let matchingTasks = tasks.filter { ids.contains($0.value) }.map { $0.key }
        for task in matchingTasks {
            task.cancel()
            tasks.removeValue(forKey: task)
        }
        for record in recordsToRemove {
            if let path = record.localURL {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        records.removeAll { ids.contains($0.id) }
        save()
        notify()
    }

    func localURL(for id: String) -> URL? {
        guard let record = records.first(where: { $0.id == id }),
              let path = record.localURL else { return nil }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func start(title: String, id: String, url: URL) {
        start(title: title, id: id, collectionID: nil, collectionTitle: nil, image: nil, url: url)
    }

    func start(title: String, id: String, collectionID: String?, collectionTitle: String?,
               image: String?, url: URL) {
        if let existing = records.first(where: { $0.id == id }), existing.state == "downloading" {
            return
        }
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "Referer": APIClient.shared.baseURL.absoluteString,
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1"
            ]
        ])
        records.removeAll { $0.id == id }
        records.append(DownloadRecord(id: id, title: title, sourceURL: url.absoluteString,
                                      collectionID: collectionID,
                                      collectionTitle: collectionTitle, image: image,
                                      localURL: nil, progress: 0, state: "starting"))
        guard let task = session.makeAssetDownloadTask(asset: asset,
                                                       assetTitle: title,
                                                       assetArtworkData: nil,
                                                       options: nil) else {
            records[records.count - 1].state = "error: không tạo được tác vụ tải"
            save()
            notify()
            return
        }
        records[records.count - 1].state = "downloading"
        task.taskDescription = id
        tasks[task] = id
        save()
        task.resume()
        notify()
    }

    func downloadAll(title: String, collectionID: String, image: String,
                     chapters: [ChapterInfo]) {
        let pending = chapters.filter { chapter in
            !records.contains(where: { $0.id == chapter.id && $0.state == "downloaded" })
        }
        pending.forEach { chapter in
            if !records.contains(where: { $0.id == chapter.id }) {
                records.append(DownloadRecord(id: chapter.id,
                                              title: "\(title) - \(chapter.name)",
                                              sourceURL: "",
                                              collectionID: collectionID,
                                              collectionTitle: title,
                                              image: image,
                                              localURL: nil,
                                              progress: 0,
                                              state: "Đang lấy link"))
            }
        }
        save()
        notify()
        fetchNext(title: title, collectionID: collectionID, image: image, chapters: pending)
    }

    private func fetchNext(title: String, collectionID: String, image: String,
                           chapters: [ChapterInfo]) {
        guard let chapter = chapters.first else {
            notify()
            return
        }
        APIClient.shared.player(chapter: chapter) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let data):
                if let url = URL(string: data.link) {
                    self.start(title: "\(title) - \(chapter.name)", id: chapter.id,
                               collectionID: collectionID, collectionTitle: title,
                               image: image, url: url)
                } else {
                    self.addFailed(title: "\(title) - \(chapter.name)", id: chapter.id,
                                   collectionID: collectionID, collectionTitle: title,
                                   image: image, message: "link không hợp lệ")
                }
            case .failure(let error):
                self.addFailed(title: "\(title) - \(chapter.name)", id: chapter.id,
                               collectionID: collectionID, collectionTitle: title,
                               image: image, message: error.description)
            }
            self.fetchNext(title: title, collectionID: collectionID, image: image,
                           chapters: Array(chapters.dropFirst()))
        }
    }

    private func addFailed(title: String, id: String, collectionID: String,
                           collectionTitle: String, image: String, message: String) {
        records.removeAll { $0.id == id }
        records.append(DownloadRecord(id: id, title: title, sourceURL: "",
                                      collectionID: collectionID, collectionTitle: collectionTitle,
                                      image: image, localURL: nil,
                                      progress: 0, state: "error: \(message)"))
        save()
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
        records[index].progress = expected > 0 ? min(loaded / expected, 1) : -1
        save()
        notify()
    }

    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let id = tasks[assetDownloadTask],
              let index = records.firstIndex(where: { $0.id == id }) else { return }
        let destinationDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationDirectory,
                                                  withIntermediateDirectories: true,
                                                  attributes: nil)
        let destination = destinationDirectory.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            records[index].localURL = destination.path
        } catch {
            records[index].state = "error: không lưu được video (\(error.localizedDescription))"
        }
        records[index].progress = 1
        if records[index].localURL != nil {
            records[index].state = "downloaded"
        }
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
        } else if records[index].state != "downloaded" {
            records[index].state = "error: tải kết thúc nhưng không tạo được file"
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
