import HotwireNative
import UIKit
import WebKit

final class ExternalWebViewController: UIViewController {
  private let url: URL
  private lazy var webView: WKWebView = {
    // 使用 Hotwire.config.makeWebView 以保持相同配置（cookies/processPool/userAgent）
    return Hotwire.config.makeWebView()
  }()
  
  init(url: URL) {
    self.url = url
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    setupWebView()
    loadURL()
  }
  
  private func setupWebView() {
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.topAnchor.constraint(equalTo: view.topAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
  }
  
  private func loadURL() {
    let req = URLRequest(url: url)
    webView.load(req)
  }
}
