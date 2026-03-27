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

    /// Horizontal scale for ticks and labels; swap the whole value to change zoom.
    var layout: TimelineLayoutProvider = TimelineLayoutProvider(pointsPerSecond: 80) {
        didSet {
            guard layout != oldValue else { return }
            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    private var pointsPerSecond: CGFloat { layout.pointsPerSecond }

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
        guard let ctx = UIGraphicsGetCurrentContext(), pointsPerSecond > 0 else { return }

        let halfPx      = pointsPerSecond / 2   // points per 0.5 s interval
        let majorH: CGFloat = 10                // major tick height (1 s)
        let minorH: CGFloat = 5                 // minor tick height (0.5 s)
        let width   = bounds.width
        let bottomY = bounds.height

        let tickColor  = UIColor.tertiaryLabel.resolvedColor(with: traitCollection).cgColor
        let totalTicks = Int(width / halfPx) + 1

        for i in 0 ..< totalTicks {
            let x = CGFloat(i) * halfPx
            guard x <= width else { break }

            let isMajor   = (i % 2 == 0)
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
        guard pointsPerSecond > 0, bounds.width > 0 else { return }

        let maxSecond = Int(bounds.width / pointsPerSecond)
        let requiredCount = maxSecond + 1

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
            let x = layout.xPosition(forSeconds: Double(second))
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
