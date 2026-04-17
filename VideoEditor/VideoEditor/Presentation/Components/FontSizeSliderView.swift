//
// FontSizeSliderView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Vertical font-size slider: gray wedge track + white circular thumb.
//  Extracted as a reusable control for the text editor sheet and similar UI.
//

import UIKit

@MainActor
final class FontSizeSliderView: UIControl {

    private let trackLayer = CAShapeLayer()
    private let knobView = UIView()

    private let knobSize: CGFloat = 26
    private(set) var minimumValue: CGFloat = 18
    private(set) var maximumValue: CGFloat = 96
    private(set) var value: CGFloat = 48 {
        didSet {
            value = min(max(value, minimumValue), maximumValue)
            setNeedsLayout()
        }
    }

    /// Optional callback invoked when the value changes.
    var onValueChanged: ((CGFloat) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        trackLayer.fillColor = UIColor.white.withAlphaComponent(0.4).cgColor
        trackLayer.strokeColor = nil
        layer.addSublayer(trackLayer)

        knobView.backgroundColor = .white
        knobView.layer.cornerRadius = knobSize / 2
        knobView.layer.cornerCurve = .continuous
        knobView.layer.shadowColor = UIColor.black.cgColor
        knobView.layer.shadowOpacity = 0.15
        knobView.layer.shadowRadius = 4
        knobView.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(knobView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    func configure(minimumValue: CGFloat, maximumValue: CGFloat, initialValue: CGFloat) {
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.value = min(max(initialValue, minimumValue), maximumValue)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Gray wedge: wide at the top, narrow at the bottom.
        let insetX: CGFloat = bounds.width * 0.35
        let topWidth: CGFloat = bounds.width - insetX * 2
        let bottomWidth: CGFloat = max(topWidth * 0.25, 2)
        let path = UIBezierPath()
        let topY: CGFloat = bounds.minY + 8
        let bottomY: CGFloat = bounds.maxY - 8

        path.move(to: CGPoint(x: bounds.midX - topWidth / 2, y: topY))
        path.addLine(to: CGPoint(x: bounds.midX + topWidth / 2, y: topY))
        path.addLine(to: CGPoint(x: bounds.midX + bottomWidth / 2, y: bottomY))
        path.addLine(to: CGPoint(x: bounds.midX - bottomWidth / 2, y: bottomY))
        path.close()

        trackLayer.path = path.cgPath

        // Map value to 0…1 from bottom to top of the track.
        let t: CGFloat
        if maximumValue > minimumValue {
            t = (value - minimumValue) / (maximumValue - minimumValue)
        } else {
            t = 0.5
        }
        let usableHeight = bottomY - topY
        let knobCenterY = bottomY - t * usableHeight
        knobView.bounds = CGRect(x: 0, y: 0, width: knobSize, height: knobSize)
        knobView.center = CGPoint(x: bounds.midX, y: knobCenterY)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)

        var newCenterY = knobView.center.y + translation.y
        let topY = bounds.minY + 8
        let bottomY = bounds.maxY - 8
        newCenterY = min(max(newCenterY, topY), bottomY)

        // Map knob Y back to value (bottom = min, top = max).
        let usableHeight = bottomY - topY
        let t = usableHeight > 0 ? (bottomY - newCenterY) / usableHeight : 0
        let newValue = minimumValue + t * (maximumValue - minimumValue)
        value = newValue
        onValueChanged?(value)
        sendActions(for: .valueChanged)
    }
}

