import UIKit

/// Turns a button's symbol while work runs: each turn eases in and out. When
/// the work ends the symbol finishes its turn, swaps to a check mark for a
/// moment (the system replace, down and up) and swaps back.
final class CNSymbolSpinner {
  weak var view: UIImageView?
  private var active = false
  /// Bumped on every start, so a late check mark from an earlier run is
  /// dropped.
  private var run = 0

  private static let spinKey = "cnSpin"
  private static let doneKey = "cnSpinDone"
  private static let turn: CFTimeInterval = 1.1
  private static let hold: TimeInterval = 1.1

  /// The image view the turn was put on. The button may swap its image
  /// view meanwhile (e.g. while its tab is hidden), so the stop goes here.
  private weak var animated: UIImageView?

  /// iOS takes a view's animations off while it is out of the window and
  /// puts them back when it returns, so nothing turns off screen: the state
  /// is only noted, and settled when the view comes back (see [Watcher]).
  func set(active: Bool) {
    guard let v = view else { return }
    attachWatcher(to: v)
    let was = self.active
    self.active = active
    guard v.window != nil else {
      v.layer.removeAnimation(forKey: Self.spinKey)
      animated = nil
      return
    }
    if active {
      if was && animated === v { return }
      if let old = animated, old !== v { old.layer.removeAnimation(forKey: Self.spinKey) }
      start(v)
    } else if was, let target = animated {
      if target !== v { v.layer.removeAnimation(forKey: Self.spinKey) }
      stop(target)
      animated = nil
    } else {
      v.layer.removeAnimation(forKey: Self.spinKey)
      animated = nil
    }
  }

  /// The view came into a window: turn if work is still running, otherwise
  /// drop any turn iOS put back.
  fileprivate func viewDidEnterWindow(_ v: UIImageView) {
    settle(v)
    // iOS may put the old turn back a moment later: look again.
    DispatchQueue.main.async { [weak self, weak v] in
      if let v { self?.settle(v) }
    }
  }

  private func settle(_ v: UIImageView) {
    guard v === view, v.window != nil else { return }
    if active {
      if animated !== v || v.layer.animation(forKey: Self.spinKey) == nil { start(v) }
    } else {
      v.layer.removeAnimation(forKey: Self.spinKey)
      v.layer.transform = CATransform3DIdentity
      animated = nil
    }
  }

  private func attachWatcher(to v: UIImageView) {
    if v.subviews.contains(where: { $0 is Watcher }) { return }
    let watcher = Watcher(frame: .zero)
    watcher.isUserInteractionEnabled = false
    watcher.spinner = self
    v.addSubview(watcher)
  }

  private func start(_ v: UIImageView) {
    run += 1
    animated = v
    let layer = v.layer
    let from = angle(of: v)
    layer.removeAllAnimations()
    let spin = CABasicAnimation(keyPath: "transform.rotation.z")
    spin.fromValue = from
    spin.toValue = from + 2 * .pi
    spin.duration = Self.turn
    spin.repeatCount = .infinity
    spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    layer.add(spin, forKey: Self.spinKey)
  }

  private func stop(_ v: UIImageView) {
    let layer = v.layer
    // Off screen (its tab hidden) the settle never plays out right and the
    // turn would carry on when it comes back: just clear it.
    guard v.window != nil else {
      layer.removeAllAnimations()
      layer.transform = CATransform3DIdentity
      return
    }
    let from = angle(of: v)
    layer.removeAnimation(forKey: Self.spinKey)
    let settle = CABasicAnimation(keyPath: "transform.rotation.z")
    settle.fromValue = from
    settle.toValue = 2 * CGFloat.pi
    settle.duration = 0.2 + 0.5 * Double((2 * .pi - from) / (2 * .pi))
    settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
    let current = run
    CATransaction.begin()
    CATransaction.setCompletionBlock { [weak self, weak v] in
      guard let self = self, let v = v, !self.active, self.run == current else { return }
      self.showCheck(v)
    }
    layer.add(settle, forKey: Self.doneKey)
    CATransaction.commit()
  }

  private func showCheck(_ v: UIImageView) {
    guard #available(iOS 17.0, *), let arrows = v.image,
          let check = UIImage(systemName: "checkmark", withConfiguration: arrows.symbolConfiguration)
    else { return }
    v.setSymbolImage(check, contentTransition: .replace.downUp)
    // The arrows come back even if a new run has started meanwhile.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.hold) { [weak v] in
      v?.setSymbolImage(arrows, contentTransition: .replace.downUp)
    }
  }

  /// Current angle in [0, 2π).
  private func angle(of v: UIView) -> CGFloat {
    let raw = (v.layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0
    return raw < 0 ? raw + 2 * .pi : raw
  }
}

/// A zero-size view inside the symbol that tells when it enters a window.
private final class Watcher: UIView {
  weak var spinner: CNSymbolSpinner?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil, let v = superview as? UIImageView else { return }
    spinner?.viewDidEnterWindow(v)
  }
}
