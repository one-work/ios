import HotwireNative
import Foundation
import UIKit
import WebKit

// 让跨域 http/https 链接在 App 原生 WebView 中打开， 而不是弹 Safari 或跳到系统浏览器
final class ExternalRouteDecisionHandler: RouteDecisionHandler {
  public let name: String = "external"

  func matches(proposal: VisitProposal, configuration: Navigator.Configuration) -> Bool {
    let location = proposal.url

    // 只处理 http/https，避免 mailto:、tel: 等被错误拦截
    guard location.scheme == "http" || location.scheme == "https" else {
      return false
    }

    return true
  }

  func handle(proposal: VisitProposal, configuration: Navigator.Configuration, navigator: Navigating) -> Router.Decision {
    print("------------------Routing \(proposal.url.absoluteString)")
    guard let navigator = navigator as? Navigator else { return .cancel }

    let vc = WebViewController(url: proposal.url, navigator: navigator)
    navigator.activeNavigationController.pushViewController(vc, animated: true)
    navigator.externalSession.visit(vc, options: proposal.options)
    return .cancel
  }
}

final class ExternalWebSession: NSObject, SessionDelegate {
  let session: Session
  private weak var navigator: Navigator?
  /// 导航栈中是否还有本 Session 的存活页面
  private var hasLivePages = false

  init(navigator: Navigator) {
    self.navigator = navigator
    session = Session(webView: Hotwire.config.makeWebView())
    super.init()
    session.delegate = self
  }

  // 所有页面都已退出，下次 visit 需要强制整页加载（让 JS 重新执行）
  func markIdle() {
    hasLivePages = false
  }

  func visit(_ vc: WebViewController, options: VisitOptions) {
    vc.isExternal = true
    vc.externalSession = self

    // 重新进入（此前页面已全部退出）→ 强制 reload，不走 Turbo 快照恢复
    let needsFreshLoad = !hasLivePages
    hasLivePages = true
    
    let currentHost = session.topmostVisitable?.currentVisitableURL.host
    let needsColdBoot = currentHost != nil && currentHost != vc.initialVisitableURL.host
    session.visit(vc, options: options, reload: needsFreshLoad || needsColdBoot)
  }

  // 外部 Session 内的 Turbo 导航：根据 action 执行对应的 UI 操作
  func session(_ session: Session, didProposeVisit proposal: VisitProposal) {
    let vc = WebViewController(url: proposal.url, navigator: navigator)
    let navController = session.activeVisitable?.visitableViewController.navigationController

    switch proposal.options.action {
    case .replace:
      // 替换当前页面：不增加导航栈层级
      replaceViewController(vc, in: navController, options: proposal.options)
    case .restore:
      // 恢复页面：如果栈中已存在相同 URL，pop 到该页面；否则按 advance 处理
      restoreOrAdvance(vc, in: navController, options: proposal.options)
    default:
      // advance 或其他：正常 push
      navController?.pushViewController(vc, animated: true)
      self.visit(vc, options: proposal.options)
    }
  }

  private func replaceViewController(_ vc: WebViewController, in nav: UINavigationController?, options: VisitOptions) {
    guard let nav = nav else { return }

    var vcs = nav.viewControllers
    guard !vcs.isEmpty else {
      nav.setViewControllers([vc], animated: false)
      self.visit(vc, options: options)
      return
    }

    // 替换栈顶，保持其余页面不变
    vcs[vcs.count - 1] = vc
    nav.setViewControllers(vcs, animated: false)
    self.visit(vc, options: options)
  }

  private func restoreOrAdvance(_ vc: WebViewController, in nav: UINavigationController?, options: VisitOptions) {
    guard let nav = nav else { return }
    
    // 查找是否已有相同 URL 的页面在栈中
    if let existingIndex = nav.viewControllers.firstIndex(where: {($0 as? WebViewController)?.initialVisitableURL == vc.initialVisitableURL}) {
      // pop 到已有页面
      let targetVC = nav.viewControllers[existingIndex]
      nav.popToViewController(targetVC, animated: true)
      // 不需要重新 visit，因为页面已经存在
    } else {
      // 没有找到，按 advance 处理
      nav.pushViewController(vc, animated: true)
      self.visit(vc, options: options)
    }
  }

  func session(_ session: Session, didProposeVisitToCrossOriginRedirect location: URL) {
    session.webView.load(URLRequest(url: location))
  }

  func session(_ session: Session, didFailRequestForVisitable visitable: Visitable, error: HotwireNativeError) {
    print("External session visit failed: \(error)")
  }

  func session(_ session: Session, decidePolicyFor navigationAction: WKNavigationAction) -> WebViewPolicyManager.Decision {
    .allow
  }

  func sessionWebViewProcessDidTerminate(_ session: Session) {
    session.reload()
  }
}
