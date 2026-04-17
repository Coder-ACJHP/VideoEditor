//
// EditorCanvasTextOverlayView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Text overlay on the preview canvas: drag, pinch scale, rotate.
//  Position is written to `EditorViewModel` as normalized `TransformEffect`.

import UIKit

@MainActor
protocol EditorCanvasTextOverlayViewDelegate: AnyObject {
    func canvasTextOverlayView(_ view: EditorCanvasTextOverlayView, didUpdate transform: TransformEffect)
    /// Single tap makes this text clip active (keeps timeline selection in sync).
    func canvasTextOverlayViewDidRequestActivation(_ view: EditorCanvasTextOverlayView)
}

/// Scales `descriptor` typography to the canvas size (1080p reference height).
@MainActor
final class EditorCanvasTextOverlayView: UIView, UIGestureRecognizerDelegate {

    weak var delegate: EditorCanvasTextOverlayViewDelegate?

    /// Stable `MediaClip.id` or a temporary id for an in-sheet draft row (updated when reusing from the render pool).
    private(set) var clipID: UUID

    private(set) var descriptor: TextOverlayDescriptor
    private(set) var normalizedTransform: TransformEffect

    private let selectionChrome = UIView()
    private let container = UIView()
    private let label = UILabel()

    private var initialTransform = TransformEffect.identity
    private var initialPinchSize = CGSize.zero
    private var initialRotation: CGFloat = 0
    private var initialCenterNorm = CGPoint.zero

    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!

    init(clipID: UUID, descriptor: TextOverlayDescriptor, transform: TransformEffect) {
        self.clipID = clipID
        self.descriptor = descriptor
        self.normalizedTransform = transform
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        setupHierarchy()
        applyDescriptorToLabel()
        layoutContainerForCanvasSize(.zero)
        setupGestures()
    }

    /// Active text on timeline / canvas: 2pt square-corner yellow border (matches timeline handle color).
    func setCanvasSelectionActive(_ active: Bool) {
        selectionChrome.isHidden = !active
    }

    /// Only the active text selection (timeline or canvas) can be moved, scaled, or rotated.
    func setTransformGesturesEnabled(_ enabled: Bool) {
        panGesture.isEnabled = enabled
        pinchGesture.isEnabled = enabled
        rotationGesture.isEnabled = enabled
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(descriptor: TextOverlayDescriptor) {
        self.descriptor = descriptor
        applyDescriptorToLabel()
        setNeedsLayout()
    }

    func update(transform: TransformEffect) {
        normalizedTransform = transform
        layoutContainerForCanvasSize(bounds.size)
    }

    /// Rebinds a pooled overlay to another clip id and content (`EditorRenderView` reuse).
    func applyConfiguration(clipID: UUID, descriptor: TextOverlayDescriptor, transform: TransformEffect) {
        self.clipID = clipID
        self.descriptor = descriptor
        normalizedTransform = transform
        applyDescriptorToLabel()
        layoutContainerForCanvasSize(bounds.size)
    }

    func prepareForPooling() {
        delegate = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutContainerForCanvasSize(bounds.size)
    }

    private func setupHierarchy() {
        let cfg = TimelineConfiguration.default
        selectionChrome.isUserInteractionEnabled = false
        selectionChrome.backgroundColor = .clear
        selectionChrome.layer.borderWidth = cfg.selectionBorderWidth
        selectionChrome.layer.borderColor = cfg.selectionColor.cgColor
        selectionChrome.layer.cornerRadius = 0
        selectionChrome.isHidden = true

        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        container.backgroundColor = .clear
        addSubview(container)
        container.addSubview(label)
        addSubview(selectionChrome)
    }

    private func applyDescriptorToLabel() {
        label.text = descriptor.text.isEmpty ? String(localized: "Text…") : descriptor.text
        label.textAlignment = nsTextAlignment(descriptor.alignmentMode)
        label.textColor = UIColor(hexString: descriptor.textColorHex)
        let fontSize = scaledPointSizeForCanvas(height: max(bounds.height, 1))
        label.font = UIFont(name: descriptor.fontName, size: fontSize)
            ?? .systemFont(ofSize: fontSize, weight: .semibold)
        container.backgroundColor = descriptor.backgroundColorHex.map { UIColor(hexString: $0) }
        container.layer.cornerRadius = 4
        container.clipsToBounds = true
    }

    private func scaledPointSizeForCanvas(height: CGFloat) -> CGFloat {
        max(10, descriptor.fontSize * (height / 1080))
    }

    private func layoutContainerForCanvasSize(_ canvasSize: CGSize) {
        guard canvasSize.width > 8, canvasSize.height > 8 else { return }

        let w = max(normalizedTransform.normalizedSize.width * canvasSize.width, 44)
        let baseHeightFromTransform = normalizedTransform.normalizedSize.height * canvasSize.height
        let cx = normalizedTransform.normalizedCenter.x * canvasSize.width
        let cy = normalizedTransform.normalizedCenter.y * canvasSize.height

        // Scale font to the live canvas height so preview matches the main editor.
        let fontSize = scaledPointSizeForCanvas(height: canvasSize.height)
        label.font = UIFont(name: descriptor.fontName, size: fontSize)
            ?? .systemFont(ofSize: fontSize, weight: .semibold)

        // Size to text height so multi-line input grows the box automatically.
        let horizontalInset: CGFloat = 6
        let verticalInset: CGFloat = 4
        let availableLabelWidth = max(w - horizontalInset * 2, 1)
        label.preferredMaxLayoutWidth = availableLabelWidth
        let fittingSize = label.sizeThatFits(
            CGSize(width: availableLabelWidth, height: .greatestFiniteMagnitude)
        )
        let contentHeight = fittingSize.height + verticalInset * 2
        let resolvedHeight = max(max(baseHeightFromTransform, contentHeight), 36)

        container.bounds = CGRect(x: 0, y: 0, width: w, height: resolvedHeight)
        container.center = CGPoint(x: cx, y: cy)
        let rotation = CGAffineTransform(rotationAngle: normalizedTransform.rotationAngle)
        container.transform = rotation

        selectionChrome.bounds = container.bounds
        selectionChrome.center = container.center
        selectionChrome.transform = rotation

        label.frame = container.bounds.insetBy(dx: horizontalInset, dy: verticalInset)
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        pan.isEnabled = false
        panGesture = pan

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = self
        pinch.isEnabled = false
        pinchGesture = pinch

        let rot = UIRotationGestureRecognizer(target: self, action: #selector(onRotate(_:)))
        rot.delegate = self
        rot.isEnabled = false
        rotationGesture = rot

        container.addGestureRecognizer(pan)
        container.addGestureRecognizer(pinch)
        container.addGestureRecognizer(rot)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTapToActivate))
        tap.cancelsTouchesInView = false
        container.addGestureRecognizer(tap)
    }

    @objc private func onTapToActivate() {
        delegate?.canvasTextOverlayViewDidRequestActivation(self)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let canvasSize = bounds.size
        guard canvasSize.width > 8, canvasSize.height > 8 else { return }

        switch g.state {
        case .began:
            initialTransform = normalizedTransform
            initialCenterNorm = initialTransform.normalizedCenter
        case .changed:
            let t = g.translation(in: self)
            let dx = t.x / canvasSize.width
            let dy = t.y / canvasSize.height
            var next = initialTransform
            next.normalizedCenter = CGPoint(
                x: clamp01(initialCenterNorm.x + dx),
                y: clamp01(initialCenterNorm.y + dy)
            )
            normalizedTransform = next
            layoutContainerForCanvasSize(canvasSize)
        case .ended, .cancelled:
            delegate?.canvasTextOverlayView(self, didUpdate: normalizedTransform)
        default:
            break
        }
    }

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        let canvasSize = bounds.size
        guard canvasSize.width > 8, canvasSize.height > 8 else { return }

        switch g.state {
        case .began:
            initialTransform = normalizedTransform
            initialPinchSize = initialTransform.normalizedSize
        case .changed:
            let s = max(0.35, min(g.scale, 4.0))
            var next = initialTransform
            let nw = clamp01(initialPinchSize.width * s)
            let nh = clamp01(initialPinchSize.height * s)
            next.normalizedSize = CGSize(width: max(nw, 0.08), height: max(nh, 0.04))
            normalizedTransform = next
            layoutContainerForCanvasSize(canvasSize)
        case .ended, .cancelled:
            g.scale = 1
            delegate?.canvasTextOverlayView(self, didUpdate: normalizedTransform)
        default:
            break
        }
    }

    @objc private func onRotate(_ g: UIRotationGestureRecognizer) {
        let canvasSize = bounds.size
        guard canvasSize.width > 8 else { return }

        switch g.state {
        case .began:
            initialTransform = normalizedTransform
            initialRotation = initialTransform.rotationAngle
        case .changed:
            var next = initialTransform
            next.rotationAngle = initialRotation + g.rotation
            normalizedTransform = next
            layoutContainerForCanvasSize(canvasSize)
        case .ended, .cancelled:
            g.rotation = 0
            delegate?.canvasTextOverlayView(self, didUpdate: normalizedTransform)
        default:
            break
        }
    }

    private func clamp01(_ v: CGFloat) -> CGFloat {
        min(max(v, 0), 1)
    }

    private func nsTextAlignment(_ mode: TextOverlayTextAlignment) -> NSTextAlignment {
        switch mode {
        case .natural: return .natural
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}
