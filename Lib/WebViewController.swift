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

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    if self.initialVisitableURL.path == "/bluetooth/menus" {
      navigator?.externalSession.session.reload() // 会触发 main + modal session 刷新（使用库的 API）
    }
  }

  /// 以 modal 呈现的页面（即表单页）：右上角放「关闭」，替代 submit
  private func addModalCloseButtonIfNeeded() {
    if self.initialVisitableURL.path != "/bluetooth/menus" { return }

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
