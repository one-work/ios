import HotwireNative
import Foundation
import UIKit
import WebKit

/// 让跨域 http/https 链接在 App 原生 WebView 中打开，
/// 而不是弹 Safari 或跳到系统浏览器。
final class CrossOriginWebViewRouteDecisionHandler: RouteDecisionHandler {
  public let name: String = "cross-origin-webview"

  public init() {}
  
  /// 防止新 Session 被释放
      private var externalSessions: [ObjectIdentifier: ExternalWebSession] = [:]

  func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
    let location = proposal.url
    
    // 只处理 http/https，避免 mailto:、tel: 等被错误拦截
    guard location.scheme == "http" || location.scheme == "https" else {
      return false
    }

    let allowedHosts = ["app-demo.xcprinter.com"]
    return allowedHosts.contains(location.host ?? "")
  }
  
  func handle(proposal: VisitProposal, configuration: Navigator.Configuration, navigator: Navigating) -> Router.Decision {
    print("------------------Routing \(proposal.url.absoluteString)")
    let external = ExternalWebSession(url: proposal.url)
            externalSessions[ObjectIdentifier(external.viewController)] = external
            navigator.activeNavigationController.pushViewController(external.viewController, animated: true)
    return .cancel
  }
}


final class ExternalWebSession: NSObject, SessionDelegate {
    let session: Session
    let viewController: VisitableViewController

    init(url: URL) {
        session = Session(webView: Hotwire.config.makeWebView())
        viewController = VisitableViewController(url: url)
        super.init()
        session.delegate = self
        session.visit(viewController)
    }

    // MARK: - SessionDelegate 必须实现的 5 个方法

    /// app-demo 内部的 Turbo 链接：正常 push 新页面
    func session(_ session: Session, didProposeVisit proposal: VisitProposal) {
        let vc = VisitableViewController(url: proposal.url)
        viewController.navigationController?.pushViewController(vc, animated: true)
        session.visit(vc, options: proposal.options)
    }

    /// 外部 session 内又重定向到别的域名：在当前 webview 原地加载即可
    func session(_ session: Session, didProposeVisitToCrossOriginRedirect location: URL) {
        session.webView.load(URLRequest(url: location))
    }

    func session(_ session: Session, didFailRequestForVisitable visitable: Visitable, error: HotwireNativeError) {
        print("External session visit failed: \(error)")
    }

    /// 外部 session 内的导航全部放行（浏览器行为）
    func session(_ session: Session, decidePolicyFor navigationAction: WKNavigationAction) -> WebViewPolicyManager.Decision {
        .allow
    }

    func sessionWebViewProcessDidTerminate(_ session: Session) {
        session.reload()
    }
}
