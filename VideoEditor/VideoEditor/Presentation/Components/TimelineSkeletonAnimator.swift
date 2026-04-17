//
// TimelineSkeletonAnimator
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.


import UIKit

// MARK: - TimelineSkeletonAnimator

/// Manages skeleton loading animations for the timeline tracks.
/// `stackView` is used only as a layout reference (lane frames). Subviews are added to `overlayHost`, never to the stack.
final class TimelineSkeletonAnimator {

    private weak var overlayContainer: UIView?

    /// Pins a transparent overlay to the stack’s frame and adds one shimmer per arranged lane.
    /// - Parameters:
    ///   - stackView: Reference for lane positions and heights only; its hierarchy is not modified.
    ///   - overlayHost: Must be an ancestor of `stackView` (typically the scroll content view). The overlay is inserted above the stack.
    func start(stackView: UIStackView, overlayHost: UIView) {
        stop()

        guard stackView.superview === overlayHost else {
            assertionFailure("overlayHost must be the direct superview of stackView")
            return
        }

        let lanes = stackView.arrangedSubviews
        guard !lanes.isEmpty else { return }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false

        overlayHost.insertSubview(container, aboveSubview: stackView)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: stackView.topAnchor),
            container.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
        ])

        for trackView in lanes {
            let shimmerView = ShimmerView()
            shimmerView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(shimmerView)

            NSLayoutConstraint.activate([
                shimmerView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                shimmerView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                shimmerView.topAnchor.constraint(equalTo: trackView.topAnchor),
                shimmerView.heightAnchor.constraint(equalTo: trackView.heightAnchor),
            ])
        }

        overlayContainer = container
    }

    /// Stops animations, removes the overlay, and releases references.
    func stop() {
        if let container = overlayContainer {
            for case let shimmer as ShimmerView in container.subviews {
                shimmer.stopAnimating()
            }
            container.removeFromSuperview()
        }
        overlayContainer = nil
    }
}

// MARK: - ShimmerView

private struct ShimmerAnimationStyle {
    /// Active sweep length (start/end point travel).
    var duration: CFTimeInterval = 1.15
    /// Idle gap before the loop repeats (outer group duration = duration + interval).
    var interval: CFTimeInterval = 0.45
}

private final class ShimmerView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let timelineConfig = TimelineConfiguration.default
    private let shimmerStyle = ShimmerAnimationStyle()

    /// Normalized points: band enters from the left and exits right (matches animation from→to).
    private var startPointAnimationFromValue: NSValue { NSValue(cgPoint: CGPoint(x: -0.95, y: 0.5)) }
    private var startPointAnimationToValue: NSValue { NSValue(cgPoint: CGPoint(x: 0.92, y: 0.5)) }
    private var endPointAnimationFromValue: NSValue { NSValue(cgPoint: CGPoint(x: 0.08, y: 0.5)) }
    private var endPointAnimationToValue: NSValue { NSValue(cgPoint: CGPoint(x: 1.95, y: 0.5)) }

    private var startPointAnimation: CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "startPoint")
        animation.fromValue = startPointAnimationFromValue
        animation.toValue = startPointAnimationToValue
        animation.duration = shimmerStyle.duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        return animation
    }

    private var endPointAnimation: CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "endPoint")
        animation.fromValue = endPointAnimationFromValue
        animation.toValue = endPointAnimationToValue
        animation.duration = shimmerStyle.duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        return animation
    }

    private var sweepAnimationGroup: CAAnimationGroup {
        let group = CAAnimationGroup()
        group.animations = [startPointAnimation, endPointAnimation]
        group.duration = shimmerStyle.duration
        group.fillMode = .both
        group.isRemovedOnCompletion = false
        return group
    }

    private var gradientLayerAnimation: CAAnimationGroup {
        let outer = CAAnimationGroup()
        outer.animations = [sweepAnimationGroup]
        outer.duration = shimmerStyle.duration + shimmerStyle.interval
        outer.repeatCount = .infinity
        outer.fillMode = .both
        outer.isRemovedOnCompletion = false
        return outer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupShimmer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func setupShimmer() {
        isUserInteractionEnabled = false
        backgroundColor = timelineConfig.trackLaneBackgroundColor
        layer.cornerRadius = timelineConfig.trackLaneCornerRadius
        clipsToBounds = true

        updateGradientColors()
        gradientLayer.locations = [0.0, 0.5, 1.0]
        // Model state matches sweep start so the first frame matches the idle pose between loops.
        gradientLayer.startPoint = CGPoint(x: -0.95, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.08, y: 0.5)

        layer.addSublayer(gradientLayer)
        startAnimating()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else { return }
        updateGradientColors()
    }

    private func updateGradientColors() {
        let base = timelineConfig.trackLaneBackgroundColor.resolvedColor(with: traitCollection)
        if let lighter = base.mixed(with: .white, amount: 0.12),
           let darker = base.mixed(with: .black, amount: 0.08) {
            gradientLayer.colors = [lighter.cgColor, darker.cgColor, lighter.cgColor]
        } else {
            let edge = traitCollection.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.14).cgColor
                : UIColor.black.withAlphaComponent(0.08).cgColor
            gradientLayer.colors = [edge, base.cgColor, edge]
        }
    }

    fileprivate func startAnimating() {
        gradientLayer.add(gradientLayerAnimation, forKey: "shimmerAnimation")
    }

    fileprivate func stopAnimating() {
        gradientLayer.removeAnimation(forKey: "shimmerAnimation")
    }
}

// MARK: - UIColor mixing

private extension UIColor {
    /// Returns `nil` when RGB components are unavailable (should be rare after `resolvedColor`).
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor? {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else { return nil }
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1 + (a2 - a1) * amount
        )
    }
}
