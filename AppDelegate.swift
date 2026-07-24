import HotwireNative
import UIKit
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    configureAppearance()
    configureHotwire()
    return true
  }

  // MARK: UISceneSession Lifecycle
  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  // Make navigation and tab bars opaque.
  private func configureAppearance() {
    UINavigationBar.appearance().scrollEdgeAppearance = .init()
    UITabBar.appearance().scrollEdgeAppearance = .init()
  }

  private func configureHotwire() {
    Hotwire.loadPathConfiguration(
      from: [
        .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
        .server(Demo.current.appendingPathComponent("configurations/ios_v1.json"))
      ]
    )

    // Set an optional custom user agent application prefix.
    Hotwire.config.applicationUserAgentPrefix = "Hotwire Demo;"

    // Register bridge components
    Hotwire.registerBridgeComponents([
      FormComponent.self,
      MenuComponent.self,
      OverflowMenuComponent.self,
      BluetoothComponent.self
    ])

    Hotwire.registerRouteDecisionHandlers([
      AppNavigationRouteDecisionHandler(),
      CrossOriginWebViewRouteDecisionHandler(),
      SafariViewControllerRouteDecisionHandler(),
      SystemNavigationRouteDecisionHandler()
    ])

    // Set configuration options
    Hotwire.config.backButtonDisplayMode = .minimal
    Hotwire.config.showDoneButtonOnModals = true
    Hotwire.config.animateReplaceActions = true
    
    // 注入 js
    Hotwire.config.makeCustomWebView = { config in      
      let url = Bundle.main.url(forResource: "init", withExtension: "js")!
      let source = try! String(contentsOf: url, encoding: .utf8)
      let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      config.userContentController.addUserScript(userScript)

      let webView = WKWebView(frame: .zero, configuration: config)
      if #available(iOS 16.4, *) {
        webView.isInspectable = true
      }
      return webView
    }
    
    #if DEBUG
    Hotwire.config.debugLoggingEnabled = true
    #endif
  }
}
