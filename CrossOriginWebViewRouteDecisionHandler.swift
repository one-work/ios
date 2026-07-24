import HotwireNative
import Foundation

/// 让跨域 http/https 链接在 App 原生 WebView 中打开，
/// 而不是弹 Safari 或跳到系统浏览器。
final class CrossOriginWebViewRouteDecisionHandler: RouteDecisionHandler {
  public let name: String = "cross-origin-webview"

  public init() {}

  func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
    let location = proposal.url
    
    // 只处理 http/https，避免 mailto:、tel: 等被错误拦截
    guard location.scheme == "http" || location.scheme == "https" else {
      return false
    }
    
    // 与 Navigator 启动域名不同即视为跨域
    if #available(iOS 16, *) {
      return configuration.startLocation.host() != location.host()
    }
    return configuration.startLocation.host != location.host
  }
  
  func handle(proposal: VisitProposal, configuration: Navigator.Configuration, navigator: Navigating) -> Router.Decision {
    // .navigate 会让 Navigator 创建一个 VisitableViewController，
    // 并在当前 Session 的 WKWebView 中加载该 URL（普通 push，非 modal）。
    return .navigate
  }
}
