import Foundation

struct WatchHistoryItem: Codable {
    let id: String // animeId or unique key
    let animeId: String
    let animeTitle: String
    let episodeId: String
    let episodeTitle: String
    let image: String?
    let watchedAt: Date
    let playbackPosition: Double
    let duration: Double

    var progressPercent: Int {
        guard duration > 0 else { return 0 }
        let p = Int((playbackPosition / duration) * 100)
        return min(max(p, 0), 100)
    }
}

final class WatchHistoryManager {
    static let shared = WatchHistoryManager()
    static let didChange = Notification.Name("AnimeVsubWatchHistoryDidChange")

    private let storageKey = "AnimeVsub.watchHistory"
    private let maxItems = 100
    private var items: [WatchHistoryItem] = []
    private let queue = DispatchQueue(label: "git.shin.animevsub.watchhistory")

    private init() {
        loadFromStorage()
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([WatchHistoryItem].self, from: data) {
            items = saved
        }
    }

    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: WatchHistoryManager.didChange, object: nil)
        }
    }

    func allHistory() -> [WatchHistoryItem] {
        queue.sync { items }
    }

    func record(
        animeId: String,
        animeTitle: String,
        episodeId: String,
        episodeTitle: String,
        image: String?,
        position: Double,
        duration: Double
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.items.removeAll { $0.animeId == animeId }
            let item = WatchHistoryItem(
                id: "\(animeId)_\(episodeId)",
                animeId: animeId,
                animeTitle: animeTitle,
                episodeId: episodeId,
                episodeTitle: episodeTitle,
                image: image,
                watchedAt: Date(),
                playbackPosition: position,
                duration: duration
            )
            self.items.insert(item, at: 0)
            if self.items.count > self.maxItems {
                self.items = Array(self.items.prefix(self.maxItems))
            }
            self.saveToStorage()
        }
    }

    func remove(animeId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.items.removeAll { $0.animeId == animeId }
            self.saveToStorage()
        }
    }

    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.items.removeAll()
            self.saveToStorage()
        }
    }
}
