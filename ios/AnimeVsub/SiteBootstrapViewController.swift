import UIKit
import WebKit

final class SiteBootstrapViewController: UIViewController, WKNavigationDelegate {
    private let initialURL: URL
    private let onReady: (URL) -> Void
    private let webView: WKWebView
    private let statusLabel = UILabel()

    init(url: URL, onReady: @escaping (URL) -> Void) {
        self.initialURL = url
        self.onReady = onReady
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kết nối website"
        view.backgroundColor = .black
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Đang mở website… Nếu có xác minh, hãy hoàn tất trong cửa sổ này."
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 12)
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        let continueButton = UIButton(type: .system)
        continueButton.setTitle("Đã tải trang — lấy dữ liệu", for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = UIColor(red: 0.82, green: 0.18, blue: 0.45, alpha: 1)
        continueButton.layer.cornerRadius = 6
        continueButton.addTarget(self, action: #selector(continueLoading), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        [statusLabel, webView, continueButton].forEach { view.addSubview($0) }
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            statusLabel.heightAnchor.constraint(equalToConstant: 34),
            webView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -6),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            continueButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            continueButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        webView.load(URLRequest(url: initialURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            statusLabel.text = "Đã mở: \(url.host ?? url.absoluteString)\nNếu trang yêu cầu xác minh, hãy hoàn tất rồi bấm nút bên dưới."
        }
    }

    @objc private func continueLoading() {
        guard let url = webView.url else { return }
        _ = APIClient.shared.setBaseURL(url.absoluteString)
        syncCookies {
            self.onReady(url)
        }
    }

    private func syncCookies(completion: @escaping () -> Void) {
        guard #available(iOS 11.0, *) else {
            completion()
            return
        }
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let storage = HTTPCookieStorage.shared
            cookies.forEach { storage.setCookie($0) }
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
