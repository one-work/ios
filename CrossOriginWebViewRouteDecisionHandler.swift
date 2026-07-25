import HotwireNative
import Foundation

/// 让跨域 http/https 链接在 App 原生 WebView 中打开，
/// 而不是弹 Safari 或跳到系统浏览器。
final class CrossOriginWebViewRouteDecisionHandler: RouteDecisionHandler {
  public let name: String = "cross-origin-webview"

  public init() {}

  func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
    let location = proposal.url
    // 如果已处理过（来自本 handler 的再 route），则不要再匹配
     if let params = proposal.parameters,
        let handled = params["inAppExternalHandled"] as? Bool,
        handled == true {
         return false
     }
    
    // 只处理 http/https，避免 mailto:、tel: 等被错误拦截
    guard location.scheme == "http" || location.scheme == "https" else {
      return false
    }

    let allowedHosts = ["app-demo.xcprinter.com"]
    return allowedHosts.contains(location.host ?? "")
  }
  
  func handle(proposal: VisitProposal, configuration: Navigator.Configuration, navigator: Navigating) -> Router.Decision {
    print("------------------Routing \(proposal.url.absoluteString)")
    var newParams = proposal.parameters ?? [:]
    newParams["inAppExternalHandled"] = true
    DispatchQueue.main.async {
      navigator.route(proposal.url, options: proposal.options, parameters: newParams)
    }
    return .cancel
  }
}
