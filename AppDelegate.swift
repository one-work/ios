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

    // Set configuration options
    Hotwire.config.backButtonDisplayMode = .minimal
    Hotwire.config.showDoneButtonOnModals = true
    Hotwire.config.animateReplaceActions = true
    
    // 在 App 启动时配置
    Hotwire.config.makeCustomWebView = { config in
      // 1. (可选) 共享 ProcessPool 以共享 Cookie
      // config.processPool = MySharedManager.shared.processPool
      
      // 2. 准备要注入的 JS (必须监听 turbo:load 以适配 Hotwire 的页面内跳转)
      let jsSource = """
      document.addEventListener("turbo:load", function() {
          console.log("全局注入的 JS 在每次 Turbo 跳转后都执行了！");
          // 你的业务逻辑，例如重新初始化某些 UI 库
      });
      """
      
      // 3. 创建 UserScript (注意：监听事件必须用 .atDocumentStart)
      let userScript = WKUserScript(
          source: jsSource,
          injectionTime: .atDocumentStart,
          forMainFrameOnly: true
      )
      
      // 4. 将脚本添加到当前 config 中
      config.userContentController.addUserScript(userScript)
      
      // 5. 返回配置好的 WebView 给 Hotwire
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
