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
    private var directTasks = [String: URLSessionDataTask]()
    private var records: [DownloadRecord] = []
    private lazy var directSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()
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
        for id in ids {
            directTasks[id]?.cancel()
            directTasks.removeValue(forKey: id)
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
        save()
        notify()

        probeAndStart(title: title, id: id, url: url, asset: asset)
    }

    private func probeAndStart(title: String, id: String, url: URL, asset: AVURLAsset) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(APIClient.shared.baseURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1", forHTTPHeaderField: "User-Agent")
        let task = directSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self,
                      self.records.contains(where: { $0.id == id }) else { return }
                guard error == nil, let data = data,
                      let manifest = String(data: data, encoding: .utf8),
                      manifest.contains("#EXTM3U") else {
                    let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
                    if contentType.lowercased().contains("video/") {
                        self.startAssetDownload(title: title, id: id, asset: asset)
                    } else {
                        self.setError(id: id, message: error?.localizedDescription ?? "link là iframe hoặc không phải HLS trực tiếp")
                    }
                    return
                }
                guard let index = self.records.firstIndex(where: { $0.id == id }) else { return }
                self.startDirectHLS(title: title, id: id, url: url, manifest: manifest, index: index)
            }
        }
        directTasks[id] = task
        task.resume()
    }

    private func startAssetDownload(title: String, id: String, asset: AVURLAsset) {
        guard let task = session.makeAssetDownloadTask(asset: asset,
                                                       assetTitle: title,
                                                       assetArtworkData: nil,
                                                       options: nil) else {
            setError(id: id, message: "không tạo được tác vụ tải")
            return
        }
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].state = "downloading"
        records[index].progress = -1
        task.taskDescription = id
        tasks[task] = id
        save()
        task.resume()
        notify()
    }

    private func startDirectHLS(title: String, id: String, url: URL, manifest: String, index: Int) {
        if manifest.range(of: "#EXT-X-STREAM-INF", options: .caseInsensitive) != nil {
            guard let variant = highestBandwidthVariant(in: manifest, baseURL: url) else {
                setError(id: id, message: "không tìm được playlist chất lượng")
                return
            }
            fetchManifest(title: title, id: id, url: variant, index: index)
            return
        }
        if manifest.range(of: "#EXT-X-KEY", options: .caseInsensitive) != nil {
            setError(id: id, message: "nguồn dùng mã hoá HLS; không thể tải trực tiếp trên iOS")
            return
        }
        let lines = manifest.components(separatedBy: .newlines)
        let segmentURLs = lines.compactMap { line -> URL? in
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !value.hasPrefix("#") else { return nil }
            return URL(string: value, relativeTo: url)?.absoluteURL
        }
        guard !segmentURLs.isEmpty else {
            setError(id: id, message: "playlist không có segment video")
            return
        }
        let mapURL = lines.first(where: { $0.contains("#EXT-X-MAP:") })
            .flatMap { attribute("URI", in: $0) }
            .flatMap { URL(string: $0, relativeTo: url)?.absoluteURL }
        let destinationDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        let destination = destinationDirectory.appendingPathComponent(id + ".ts")
        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
            try? FileManager.default.removeItem(at: destination)
            FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: nil)
        } catch {
            setError(id: id, message: "không tạo được file đích: \(error.localizedDescription)")
            return
        }
        records[index].state = "downloading"
        records[index].sourceURL = url.absoluteString
        records[index].localURL = destination.path
        records[index].progress = 0
        save()
        notify()
        fetchSegments(title: title, id: id, segmentURLs: segmentURLs, mapURL: mapURL,
                      destination: destination, current: 0)
    }

    private func fetchManifest(title: String, id: String, url: URL, index: Int) {
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.baseURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1", forHTTPHeaderField: "User-Agent")
        directTasks[id] = directSession.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data,
                      let manifest = String(data: data, encoding: .utf8) else {
                    self?.setError(id: id, message: error?.localizedDescription ?? "không đọc được playlist")
                    return
                }
                self?.startDirectHLS(title: title, id: id, url: url, manifest: manifest, index: index)
            }
        }
        directTasks[id]?.resume()
    }

    private func fetchSegments(title: String, id: String, segmentURLs: [URL], mapURL: URL?,
                               destination: URL, current: Int) {
        if current == 0, let mapURL = mapURL {
            fetchBytes(id: id, url: mapURL) { [weak self] data, error in
                guard let self = self, let data = data else {
                    self.setError(id: id, message: error ?? "không tải được header video")
                    return
                }
                self.append(data, to: destination, id: id)
                self.fetchSegments(title: title, id: id, segmentURLs: segmentURLs,
                                   mapURL: nil, destination: destination, current: 0)
            }
            return
        }
        guard current < segmentURLs.count else {
            guard let index = records.firstIndex(where: { $0.id == id }) else { return }
            records[index].progress = 1
            records[index].state = "downloaded"
            directTasks.removeValue(forKey: id)
            save()
            notify()
            return
        }
        fetchBytes(id: id, url: segmentURLs[current]) { [weak self] data, error in
            guard let self = self else { return }
            guard let data = data else {
                self.setError(id: id, message: error ?? "không tải được segment \(current + 1)")
                return
            }
            self.append(data, to: destination, id: id)
            if let index = self.records.firstIndex(where: { $0.id == id }) {
                self.records[index].progress = Double(current + 1) / Double(segmentURLs.count)
                self.save()
                self.notify()
            }
            self.fetchSegments(title: title, id: id, segmentURLs: segmentURLs,
                               mapURL: nil, destination: destination, current: current + 1)
        }
    }

    private func fetchBytes(id: String, url: URL, completion: @escaping (Data?, String?) -> Void) {
        var request = URLRequest(url: url)
        request.setValue(APIClient.shared.baseURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1", forHTTPHeaderField: "User-Agent")
        let task = directSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard self != nil else { return }
                if let error = error {
                    completion(nil, error.localizedDescription)
                } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    completion(nil, "HTTP \(http.statusCode)")
                } else {
                    completion(data, data == nil ? "phản hồi rỗng" : nil)
                }
            }
        }
        directTasks[id] = task
        task.resume()
    }

    private func append(_ data: Data, to url: URL, id: String) {
        guard let handle = FileHandle(forWritingAtPath: url.path) else {
            setError(id: id, message: "không mở được file đích")
            return
        }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }

    private func setError(id: String, message: String) {
        directTasks[id]?.cancel()
        directTasks.removeValue(forKey: id)
        if let index = records.firstIndex(where: { $0.id == id }) {
            if let path = records[index].localURL {
                try? FileManager.default.removeItem(atPath: path)
                records[index].localURL = nil
            }
            records[index].state = "error: \(message)"
            records[index].progress = 0
            save()
            notify()
        }
    }

    private func highestBandwidthVariant(in manifest: String, baseURL: URL) -> URL? {
        let lines = manifest.components(separatedBy: .newlines)
        var best: (bandwidth: Int, url: URL)?
        for index in 0..<max(0, lines.count - 1) where lines[index].contains("#EXT-X-STREAM-INF") {
            let bandwidth = attribute("BANDWIDTH", in: lines[index]).flatMap(Int.init) ?? 0
            let value = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard let candidate = URL(string: value, relativeTo: baseURL)?.absoluteURL else { continue }
            if best == nil || bandwidth > best!.bandwidth {
                best = (bandwidth, candidate)
            }
        }
        return best?.url
    }

    private func attribute(_ name: String, in line: String) -> String? {
        guard let range = line.range(of: "\(name)=\"") else { return nil }
        let valueStart = range.upperBound
        guard let valueEnd = line[valueStart...].firstIndex(of: "\"") else { return nil }
        return String(line[valueStart..<valueEnd])
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
