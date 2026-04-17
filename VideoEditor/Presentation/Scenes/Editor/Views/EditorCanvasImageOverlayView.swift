//
// EditorCanvasImageOverlayView
// VideoEditor
//  Created by Coder ACJHP on 18.04.2026.
//
//  Raster sticker / overlay image on the preview canvas: drag, pinch scale, rotate.
//  Preview `AVComposition` omits these clips so placement matches live UIKit editing (same idea as text).

import UIKit

@MainActor
protocol EditorCanvasImageOverlayViewDelegate: AnyObject {
    func canvasImageOverlayView(_ view: EditorCanvasImageOverlayView, didUpdate transform: TransformEffect)
    func canvasImageOverlayViewDidRequestActivation(_ view: EditorCanvasImageOverlayView)
}

@MainActor
final class EditorCanvasImageOverlayView: UIView, UIGestureRecognizerDelegate {

    weak var delegate: EditorCanvasImageOverlayViewDelegate?

    private(set) var clipID: UUID
    private(set) var imageURL: URL
    private(set) var normalizedTransform: TransformEffect

    private let selectionChrome = UIView()
    private let container = UIView()
    private let imageView = UIImageView()

    private var initialTransform = TransformEffect.identity
    private var initialPinchSize = CGSize.zero
    private var initialRotation: CGFloat = 0
    private var initialCenterNorm = CGPoint.zero

    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!

    init(clipID: UUID, imageURL: URL, transform: TransformEffect) {
        self.clipID = clipID
        self.imageURL = imageURL
        self.normalizedTransform = transform
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        setupHierarchy()
        applyImage()
        layoutContainerForCanvasSize(.zero)
        setupGestures()
    }

    func setCanvasSelectionActive(_ active: Bool) {
        selectionChrome.isHidden = !active
    }

    func setTransformGesturesEnabled(_ enabled: Bool) {
        panGesture.isEnabled = enabled
        pinchGesture.isEnabled = enabled
        rotationGesture.isEnabled = enabled
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(imageURL: URL) {
        guard self.imageURL != imageURL else { return }
        self.imageURL = imageURL
        applyImage()
        setNeedsLayout()
    }

    func update(transform: TransformEffect) {
        normalizedTransform = transform
        layoutContainerForCanvasSize(bounds.size)
    }

    func applyConfiguration(clipID: UUID, imageURL: URL, transform: TransformEffect) {
        self.clipID = clipID
        self.imageURL = imageURL
        normalizedTransform = transform
        applyImage()
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

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = String(localized: "Sticker")

        container.backgroundColor = .clear
        addSubview(container)
        container.addSubview(imageView)
        addSubview(selectionChrome)
    }

    private func applyImage() {
        if let image = UIImage(contentsOfFile: imageURL.path) {
            imageView.image = image
        } else {
            imageView.image = nil
            imageView.backgroundColor = UIColor.secondarySystemFill
        }
    }

    private func layoutContainerForCanvasSize(_ canvasSize: CGSize) {
        guard canvasSize.width > 8, canvasSize.height > 8 else { return }

        let w = max(normalizedTransform.normalizedSize.width * canvasSize.width, 44)
        let h = max(normalizedTransform.normalizedSize.height * canvasSize.height, 44)
        let cx = normalizedTransform.normalizedCenter.x * canvasSize.width
        let cy = normalizedTransform.normalizedCenter.y * canvasSize.height

        container.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        container.center = CGPoint(x: cx, y: cy)
        let rotation = CGAffineTransform(rotationAngle: normalizedTransform.rotationAngle)
        container.transform = rotation

        selectionChrome.bounds = container.bounds
        selectionChrome.center = container.center
        selectionChrome.transform = rotation

        imageView.frame = container.bounds.insetBy(dx: 2, dy: 2)
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
        delegate?.canvasImageOverlayViewDidRequestActivation(self)
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
            delegate?.canvasImageOverlayView(self, didUpdate: normalizedTransform)
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
            next.normalizedSize = CGSize(width: max(nw, 0.08), height: max(nh, 0.08))
            normalizedTransform = next
            layoutContainerForCanvasSize(canvasSize)
        case .ended, .cancelled:
            g.scale = 1
            delegate?.canvasImageOverlayView(self, didUpdate: normalizedTransform)
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
            delegate?.canvasImageOverlayView(self, didUpdate: normalizedTransform)
        default:
            break
        }
    }

    private func clamp01(_ v: CGFloat) -> CGFloat {
        min(max(v, 0), 1)
    }
}
