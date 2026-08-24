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
    Hotwire.config.applicationUserAgentPrefix = "Hotwire"

    // Register bridge components
    Hotwire.registerBridgeComponents([
      ScanComponent.self,
      BluetoothComponent.self,
      RightButtonComponent.self,
      AppleSignInComponent.self,
      OverflowMenuComponent.self
    ])

    Hotwire.registerRouteDecisionHandlers([
      AppNavigationRouteDecisionHandler(),
      ExternalRouteDecisionHandler(),
      SafariViewControllerRouteDecisionHandler(),
      SystemNavigationRouteDecisionHandler()
    ])

    // Set configuration options
    Hotwire.config.backButtonDisplayMode = .minimal
    Hotwire.config.showDoneButtonOnModals = true
    Hotwire.config.hideTabBarWhenPushed = true
    Hotwire.config.animateReplaceActions = true

    // 注入 js
    Hotwire.config.makeCustomWebView = { config in
      if let script = InjectedScriptsProvider.makeUserScript() {
        config.userContentController.addUserScript(script)
      }

      let webView = WKWebView(frame: .zero, configuration: config)
      if #available(iOS 16.4, *) {
        webView.isInspectable = true
      }
      print(webView.frame)
      print(webView.safeAreaInsets)
      webView.scrollView.contentInsetAdjustmentBehavior = .never

      return webView
    }

    Hotwire.config.debugLoggingEnabled = true
  }
}

private struct InjectedScript {
  let id: String
  let url: String
}

private enum InjectedScriptsProvider {
  static let fallback: [InjectedScript] = [
    InjectedScript(
      id: "init_turbo",
      url: "https://assets.linlishenghuo.com/assets/turbo-00000001.digested.js"
    ),
    InjectedScript(
      id: "init",
      url: "https://assets.linlishenghuo.com/assets/printer-00000097.digested.js"
    )
  ]

  static func currentScripts() -> [InjectedScript] {
    let settings = Hotwire.config.pathConfiguration.settings

    guard let items = settings["script_injections"] as? [[String: AnyHashable]] else {
      return fallback
    }

    let scripts = items.compactMap { item -> InjectedScript? in
      guard
        let id = item["id"] as? String,
        let url = item["url"] as? String,
        URL(string: url) != nil
      else {
        return nil
      }

      return InjectedScript(id: id, url: url)
    }

    return scripts.isEmpty ? fallback : scripts
  }

  static func makeUserScript() -> WKUserScript? {
    let payload = currentScripts().map {
      [
        "id": $0.id,
        "url": $0.url
      ]
    }

    guard
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let json = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    let source = """
    (() => {
      const scripts = \(json);

      for (const item of scripts) {
        if (document.getElementById(item.id)) continue;

        const script = document.createElement('script');
        script.id = item.id;
        script.src = item.url;
        script.async = false;

        script.onerror = () => {
          console.error(`注入 ${item.id} 失败：${item.url}`);
        };

        document.head.appendChild(script);
        console.debug(`注入 ${item.id} 成功：${item.url}`);
      }
    })();
    """

    return WKUserScript(
      source: source,
      injectionTime: .atDocumentEnd,
      forMainFrameOnly: true
    )
  }
}
