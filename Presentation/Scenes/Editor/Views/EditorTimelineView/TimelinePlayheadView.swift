//
//  TimelinePlayheadView.swift
//  VideoEditor
//
//  The fixed vertical cursor overlaid at the horizontal center of the timeline.
//  Drawn with CALayers for zero-overhead layout changes.
//  User interaction is disabled so all touches pass through to the scroll view beneath.
//

import UIKit

final class TimelinePlayheadView: UIView {

    // MARK: - Layers

    /// Downward-pointing triangle anchored at the top of the view.
    private let capLayer = CAShapeLayer()

    /// Hairline stem that extends from the cap tip to the bottom of the view.
    private let stemLayer = CALayer()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        layer.addSublayer(capLayer)
        layer.addSublayer(stemLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // Disable implicit animations for layout-driven layer updates.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let cx      = bounds.midX
        let capW:   CGFloat = 12   // total cap base width
        let capH:   CGFloat = 10   // cap height
        let stemW:  CGFloat = 2    // stem thickness

        // Downward-pointing isoceles triangle.
        let path = UIBezierPath()
        path.move(to:    CGPoint(x: cx - capW / 2, y: 0))  // top-left
        path.addLine(to: CGPoint(x: cx + capW / 2, y: 0))  // top-right
        path.addLine(to: CGPoint(x: cx,            y: capH)) // tip
        path.close()
        capLayer.path      = path.cgPath
        capLayer.fillColor = UIColor.white.cgColor

        // Stem from cap tip to view bottom.
        stemLayer.frame           = CGRect(x: cx - stemW / 2, y: capH,
                                           width: stemW, height: bounds.height - capH)
        stemLayer.backgroundColor = UIColor.white.cgColor
    }
}
