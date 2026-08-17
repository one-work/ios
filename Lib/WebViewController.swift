import HotwireNative
import UIKit

final class WebViewController: HotwireWebViewController, UIGestureRecognizerDelegate {
  weak var navigator: Navigator?
  weak var externalSession: ExternalWebSession? // 所属的外部 Session（弱引用，用于出栈时回通知）
  var isExternal = false  // 是否由外部 Session 打开

  init(url: URL, navigator: Navigator? = nil) {
    self.navigator = navigator
    super.init(url: url)
  }

  @MainActor required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = TouchForwardingView()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    disableEdgeEffectTouches(in: view)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    disableEdgeEffectTouches(in: view)
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

  override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    // parent == nil 说明被 pop / 移出了导航栈
    guard parent == nil, isExternal else { return }
    // 延迟一拍再判断，避免 replace 场景下新页面还没入栈导致误判
    DispatchQueue.main.async { [weak self] in
      self?.notifyExternalPageRemoved()
    }
  }

  private func notifyExternalPageRemoved() {
    guard let navigator else { return }
    let stack = navigator.activeNavigationController.viewControllers
    let stillHasExternal = stack.contains { ($0 as? WebViewController)?.isExternal == true }
    if !stillHasExternal {
      externalSession?.markIdle()
    }
  }

  // 以 modal 呈现的页面（即表单页）：右上角放「关闭」，替代 submit
  private func addModalCloseButtonIfNeeded() {
    if self.initialVisitableURL.path != "/bluetooth/menus" { return }

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(closeModal)
    )
  }

  private func disableEdgeEffectTouches(in view: UIView) {
    if view.isSystemScrollEdgeEffectView, view.isUserInteractionEnabled {
      view.isUserInteractionEnabled = false
    }

    for subview in view.subviews {
      disableEdgeEffectTouches(in: subview)
    }
  }

  @objc private func closeModal() {
    navigationController?.dismiss(animated: true)
  }
}

/// iOS 26 的 ScrollEdgeEffect 内部视图可能在 modal 转场完成后才插入。
/// 布局时扫描可能早于插入时机，因此在命中测试时兜底禁用，确保第一次弹出也不会形成点击死区。
private final class TouchForwardingView: UIView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    var hitView = super.hitTest(point, with: event)
    var disabledViews = Set<ObjectIdentifier>()

    while let currentHitView = hitView,
          let edgeEffectView = currentHitView.systemScrollEdgeEffectAncestor,
          !disabledViews.contains(ObjectIdentifier(edgeEffectView)) {
      edgeEffectView.isUserInteractionEnabled = false
      disabledViews.insert(ObjectIdentifier(edgeEffectView))
      hitView = super.hitTest(point, with: event)
    }

    return hitView
  }
}

private extension UIView {
  var isSystemScrollEdgeEffectView: Bool {
    guard !(self is TouchForwardingView) else { return false }
    return String(describing: type(of: self)).contains("ScrollEdgeEffect")
  }

  var systemScrollEdgeEffectAncestor: UIView? {
    sequence(first: self) { $0.superview }.first { $0.isSystemScrollEdgeEffectView }
  }
}
