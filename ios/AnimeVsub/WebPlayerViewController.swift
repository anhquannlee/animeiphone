import UIKit
import WebKit

final class WebPlayerViewController: UIViewController, WKNavigationDelegate {
    private let animeID: String
    private let chapterID: String
    private let siteURL: URL
    private let webView: WKWebView

    init(animeID: String, chapterID: String) {
        self.animeID = animeID
        self.chapterID = chapterID
        siteURL = URL(string: "\(APIClient.shared.baseURL.absoluteString)/phim/\(animeID)/xem-phim.html")!
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trình phát website"
        view.backgroundColor = .black
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        webView.load(URLRequest(url: siteURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let escapedID = chapterID.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function() {
          var links = document.querySelectorAll('[data-id]');
          for (var i = 0; i < links.length; i++) {
            if (links[i].getAttribute('data-id') === '\(escapedID)') {
              links[i].click();
              return true;
            }
          }
          return false;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}
