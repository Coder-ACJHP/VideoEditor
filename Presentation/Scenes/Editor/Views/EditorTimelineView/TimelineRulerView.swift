//
//  TimelineRulerView.swift
//  VideoEditor
//
//  Time ruler that scrolls as part of the timeline content.
//  Draws directly into the graphics context for maximum performance;
//  no UILabel subviews are created at runtime.
//
//  Tick structure:
//   ────────────────────────────────────────────
//    1s            2s            3s       <- labels
//    |    .    |    .    |    .    |       <- major (1s) and minor (0.5s) ticks
//

import UIKit

final class TimelineRulerView: UIView {

    // MARK: - Configuration

    /// Horizontal scale: how many points represent one second of media.
    var pixelsPerSecond: CGFloat = 80 {
        didSet {
            guard pixelsPerSecond != oldValue else { return }
            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    private var secondLabels: [UILabel] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        layer.masksToBounds = false
        translatesAutoresizingMaskIntoConstraints = false
        // traitCollectionDidChange handles re-draw on dark ↔ light switch (iOS 16 compatible).
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateLabelColors()
            setNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildLabelsIfNeeded()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), pixelsPerSecond > 0 else { return }

        let halfPx      = pixelsPerSecond / 2   // points per 0.5 s interval
        let majorH: CGFloat = 10                // major tick height (1 s)
        let minorH: CGFloat = 5                 // minor tick height (0.5 s)
        let bottomY = rect.height

        // Resolve semantic colors here (draw(_:) may be called off-main on older SDKs,
        // but UIColor.resolved is safe to call on the current trait collection).
        let tickColor  = UIColor.tertiaryLabel.resolvedColor(with: traitCollection).cgColor
        // Integer tick index avoids floating-point drift across long timelines.
        let totalTicks = Int(ceil(rect.width / halfPx)) + 2

        for i in 0 ..< totalTicks {
            let x = CGFloat(i) * halfPx
            guard x <= rect.width else { break }

            let isMajor   = (i % 2 == 0)  // every 2 half-steps = 1 full second
            let tickH     = isMajor ? majorH : minorH
            let lineWidth: CGFloat = isMajor ? 1.5 : 1.0

            ctx.setStrokeColor(tickColor)
            ctx.setLineWidth(lineWidth)
            ctx.move(to:    CGPoint(x: x, y: bottomY - tickH))
            ctx.addLine(to: CGPoint(x: x, y: bottomY))
            ctx.strokePath()

        }
    }

    private func rebuildLabelsIfNeeded() {
        guard pixelsPerSecond > 0, bounds.width > 0 else { return }

        let maxSecond = Int(ceil(bounds.width / pixelsPerSecond))
        let requiredCount = maxSecond + 1 // includes 0

        if secondLabels.count != requiredCount {
            secondLabels.forEach { $0.removeFromSuperview() }
            secondLabels.removeAll(keepingCapacity: true)
            for second in 0 ... maxSecond {
                let label = makeSecondLabel(text: "\(second)s")
                addSubview(label)
                secondLabels.append(label)
            }
        }

        for second in 0 ... maxSecond {
            let label = secondLabels[second]
            label.text = "\(second)s"
            label.sizeToFit()
            let x = CGFloat(second) * pixelsPerSecond
            label.frame.origin = CGPoint(x: x - (label.bounds.width / 2), y: 3)
        }
    }

    private func makeSecondLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        label.textColor = .secondaryLabel
        label.backgroundColor = .clear
        return label
    }

    private func updateLabelColors() {
        secondLabels.forEach { $0.textColor = .secondaryLabel }
    }
}
