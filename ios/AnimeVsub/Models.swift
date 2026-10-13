import Foundation

struct ChapterInfo: Codable {
    let id: String
    let name: String
    let extra: [String: String]?
}

struct AnimeCard: Codable {
    let animeId: String
    let image: String
    let name: String
    let lastEpisode: ChapterInfo?
    let rate: Double
    let views: Int?
    let quality: String?
    let process: String?
    let year: Int?

    enum CodingKeys: String, CodingKey {
        case animeId, image, name, lastEpisode, rate, views, quality, process, year
    }
}

struct HomeData: Codable {
    let thisSeason: [AnimeCard]
    let carousel: [AnimeCard]
    let lastUpdate: [AnimeCard]
    let preRelease: [AnimeCard]
    let nominate: [AnimeCard]
    let hotUpdate: [AnimeCard]
}

struct CategoryPage: Codable {
    let items: [AnimeCard]
    let totalPages: Int
    let currentPage: Int
    let name: String?
    let title: String?
}

struct AnimeDetail: Codable {
    let name: String
    let othername: String?
    let image: String?
    let poster: String?
    let description: String
    let rate: Double
    let countRate: Int
    let duration: String?
    let views: Int
    let quality: String?
    let trailer: String?
    let season: [Season]
    let genre: [CategoryLink]
}

struct Season: Codable {
    let id: String
    let name: String
}

struct CategoryLink: Codable {
    let name: String
    let filters: [SelectedFilter]?
}

struct SelectedFilter: Codable {
    let groupId: String
    let id: String
    let name: String
    let include: Bool?
    let exclude: Bool?
}

struct PlayerData: Codable {
    let link: String
    let type: String
    let headers: [String: String]?
    let isContent: Bool?
}
