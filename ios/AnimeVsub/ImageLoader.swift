import UIKit

final class ImageLoader {
    static let shared = ImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func image(url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image = image {
                self?.cache.setObject(image, forKey: url as NSURL)
            }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}

final class AsyncImageView: UIImageView {
    private var representedURL: URL?

    func load(url: URL) {
        representedURL = url
        image = nil
        ImageLoader.shared.image(url: url) { [weak self] image in
            guard self?.representedURL == url else { return }
            self?.image = image
        }
    }
}
