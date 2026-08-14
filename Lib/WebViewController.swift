import HotwireNative
import UIKit

final class WebViewController: HotwireWebViewController, UIGestureRecognizerDelegate {
  weak var navigator: Navigator?

  init(url: URL, navigator: Navigator? = nil) {
    self.navigator = navigator
    super.init(url: url)
  }

  @MainActor required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    //DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.view.window?.debugPaintBorders() }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    disableEdgeEffectTouches(in: visitableView)
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

  private func disableEdgeEffectTouches(in view: UIView) {
    for subview in view.subviews {
      let typeName = String(describing: type(of: subview))
      if typeName.contains("ScrollEdgeEffect"), subview.isUserInteractionEnabled {
        subview.isUserInteractionEnabled = false
      }
      disableEdgeEffectTouches(in: subview)
    }
  }

  @objc private func closeModal() {
    navigationController?.dismiss(animated: true)
  }
}

// 放在 WebViewController.swift 底部的 extension 里，或任意地方
extension UIView {
  func debugPaintBorders() {
    layer.borderWidth = 1
    layer.borderColor = UIColor.systemRed.cgColor
    subviews.forEach { $0.debugPaintBorders() }
  }
}
