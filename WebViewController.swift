import HotwireNative
import UIKit

final class WebViewController: HotwireWebViewController {
  weak var navigator: Navigator?

  init(url: URL, navigator: Navigator? = nil) {
    self.navigator = navigator
    super.init(url: url)
  }

  @MainActor required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    addModalCloseButtonIfNeeded()
  }

  /// 以 modal 呈现的页面（即表单页）：右上角放「关闭」，替代 submit
  private func addModalCloseButtonIfNeeded() {
    let properties = Hotwire.config.pathConfiguration.properties(for: "/menus$")
    guard properties["context"] as? String == "modal" else { return }

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(closeModal)
    )
  }

  @objc private func closeModal() {
    navigationController?.dismiss(animated: true)
  }
}
