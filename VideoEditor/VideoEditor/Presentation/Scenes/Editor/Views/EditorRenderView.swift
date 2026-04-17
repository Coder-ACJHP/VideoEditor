//
// EditorRenderView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Preview / playback area for the editing canvas.
//  Contains a media canvas that maintains its aspect ratio inside the view,
//  and a toggle button that lets the parent VC animate between a compact
//  (~40 % of screen) and an expanded (~65 % of screen) height.
//

import AVFoundation
import UIKit

// MARK: - Text overlay canvas binding

/// One row of UIKit text on the preview canvas (driven by `EditorViewModel` + playhead, not by `AVComposition`).
struct TextOverlayCanvasBinding: Equatable {
    let clipId: UUID
    var descriptor: TextOverlayDescriptor
    var transform: TransformEffect
    var allowsTransformGestures: Bool
    var showsSelectionChrome: Bool
}

// MARK: - Delegate

protocol EditorRenderViewDelegate: AnyObject {
    /// Fired when the user taps the expand/collapse chevron button.
    /// - Parameter isExpanding: `true` when the view should grow, `false` when it should shrink.
    func renderView(_ renderView: EditorRenderView, didRequestToggleSizeWithExpanding isExpanding: Bool)
}

@MainActor
protocol EditorRenderViewTextOverlayDelegate: AnyObject {
    func editorRenderView(
        _ renderView: EditorRenderView,
        didUpdateTextOverlayClipId clipId: UUID,
        transform: TransformEffect
    )
    /// User touched text on the canvas; align timeline selection to this clip.
    func editorRenderView(_ renderView: EditorRenderView, didRequestActivateTextClipId clipId: UUID)
}

// MARK: - EditorRenderView

/// The preview panel shown directly below the navigation bar.
///
/// Layout (compact state, 9:16 canvas example):
/// ```
/// ┌──────────────────────────────────────────────┐  ← renderView
/// │          ┌──────────────┐                    │
/// │          │              │ ← canvas (9:16)    │
/// │          │   (black)    │                    │
/// │          └──────────────┘                    │
/// │               [ ⌄ ]  ← toggleButton          │
/// └──────────────────────────────────────────────┘
/// ```
///
/// The canvas width is derived from its height via an aspect-ratio constraint,
/// so it always scales correctly when the parent changes the render view height.
final class EditorRenderView: UIView {

    // MARK: - Public

    weak var delegate: EditorRenderViewDelegate?
    weak var textOverlayDelegate: EditorRenderViewTextOverlayDelegate?

    /// Read-only expansion state; mutated via `setExpanded(_:)`.
    private(set) var isExpanded = false

    /// Compositing surface; its backing layer is the preview `AVPlayerLayer` (see `EditorVideoCanvasHostView`).
    let canvas = EditorVideoCanvasHostView()

    /// Same as `canvas.videoLayer` — use when wiring `AVPlayer` from services.
    var hostedPlayerLayer: AVPlayerLayer { canvas.videoLayer }

    /// Text overlays share the same coordinate space as the video canvas.
    private let textOverlayHost: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var textOverlayViewsByClipId: [UUID: EditorCanvasTextOverlayView] = [:]
    private var textOverlayViewPool: [EditorCanvasTextOverlayView] = []
    private let textOverlayPoolCapacity = 16
    private var activeTextOverlayClipId: UUID?

    /// Currently selected text clip on the timeline (feature rail `Edit` uses this).
    var highlightedTextOverlayClipId: UUID? { activeTextOverlayClipId }

    // MARK: - Private UI

    private lazy var toggleButton: UIButton = {
        let symConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "chevron.down", withConfiguration: symConfig)
        // Subtle pill: blends into the background while staying tappable.
        config.baseBackgroundColor = .tertiarySystemBackground
        config.baseForegroundColor = .secondaryLabel
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        btn.accessibilityLabel = "Expand preview"
        return btn
    }()

    /// Active aspect-ratio constraint; replaced (never mutated) by `setAspectRatio`.
    private var canvasAspectConstraint: NSLayoutConstraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private Setup

    private func setupView() {
        backgroundColor = .secondarySystemBackground
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(canvas)
        canvas.addSubview(textOverlayHost)
        addSubview(toggleButton)

        NSLayoutConstraint.activate([
            textOverlayHost.topAnchor.constraint(equalTo: canvas.topAnchor),
            textOverlayHost.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            textOverlayHost.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
            textOverlayHost.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
        ])

        // 9:16 portrait by default (width = height × 9/16).
        let aspectConstraint = canvas.widthAnchor.constraint(
            equalTo: canvas.heightAnchor,
            multiplier: 9.0 / 16.0
        )
        canvasAspectConstraint = aspectConstraint

        NSLayoutConstraint.activate([
            // Canvas fills vertical space above the toggle button, centered horizontally.
            canvas.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            canvas.bottomAnchor.constraint(equalTo: toggleButton.topAnchor, constant: -8),
            canvas.centerXAnchor.constraint(equalTo: centerXAnchor),
            // Guard against degenerate layout on very small render views.
            canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            aspectConstraint,

            // Toggle button: pinned to the bottom center of the render view.
            toggleButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            toggleButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Public API

    /// Updates the canvas aspect ratio constraint.
    /// - Parameter multiplier: `width / height`.
    ///   Use `9.0/16.0` for portrait TikTok/Reels, `16.0/9.0` for landscape, `1.0` for square.
    func setAspectRatio(widthToHeight multiplier: CGFloat) {
        guard multiplier > 0 else { return }
        canvasAspectConstraint?.isActive = false
        let updated = canvas.widthAnchor.constraint(
            equalTo: canvas.heightAnchor,
            multiplier: multiplier
        )
        updated.isActive = true
        canvasAspectConstraint = updated
        setNeedsLayout()
    }

    /// Syncs the button icon with the current expansion state.
    /// Call this inside (or right before) the parent VC's layout animation block
    /// so the icon transitions are in step with the spring animation.
    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        let imageName = expanded ? "chevron.up" : "chevron.down"
        let symConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        var btnConfig = toggleButton.configuration
        btnConfig?.image = UIImage(systemName: imageName, withConfiguration: symConfig)
        toggleButton.configuration = btnConfig
        toggleButton.accessibilityLabel = expanded ? "Collapse preview" : "Expand preview"
    }

    /// Applies visible text rows for the current playhead; reuses `EditorCanvasTextOverlayView` instances from a pool.
    func applyTextOverlayBindings(_ bindings: [TextOverlayCanvasBinding]) {
        let wantedIds = Set(bindings.map(\.clipId))

        for (id, view) in textOverlayViewsByClipId where !wantedIds.contains(id) {
            textOverlayViewsByClipId.removeValue(forKey: id)
            retireTextOverlayViewToPool(view)
        }

        guard !bindings.isEmpty else {
            textOverlayHost.isHidden = true
            if let active = activeTextOverlayClipId, !wantedIds.contains(active) {
                activeTextOverlayClipId = nil
            }
            return
        }
        textOverlayHost.isHidden = false

        for binding in bindings {
            if let existing = textOverlayViewsByClipId[binding.clipId] {
                existing.update(descriptor: binding.descriptor)
                existing.update(transform: binding.transform)
                existing.delegate = self
                existing.setCanvasSelectionActive(binding.showsSelectionChrome)
                existing.setTransformGesturesEnabled(binding.allowsTransformGestures)
            } else {
                let overlay = dequeueOrCreateTextOverlayView(
                    clipId: binding.clipId,
                    descriptor: binding.descriptor,
                    transform: binding.transform
                )
                overlay.delegate = self
                textOverlayViewsByClipId[binding.clipId] = overlay
                if overlay.superview == nil {
                    overlay.translatesAutoresizingMaskIntoConstraints = false
                    textOverlayHost.addSubview(overlay)
                    NSLayoutConstraint.activate([
                        overlay.topAnchor.constraint(equalTo: textOverlayHost.topAnchor),
                        overlay.leadingAnchor.constraint(equalTo: textOverlayHost.leadingAnchor),
                        overlay.trailingAnchor.constraint(equalTo: textOverlayHost.trailingAnchor),
                        overlay.bottomAnchor.constraint(equalTo: textOverlayHost.bottomAnchor),
                    ])
                }
                overlay.setCanvasSelectionActive(binding.showsSelectionChrome)
                overlay.setTransformGesturesEnabled(binding.allowsTransformGestures)
            }
        }

        for binding in bindings {
            if let v = textOverlayViewsByClipId[binding.clipId] {
                textOverlayHost.bringSubviewToFront(v)
            }
        }

        if let active = activeTextOverlayClipId, !wantedIds.contains(active) {
            activeTextOverlayClipId = nil
        }
    }

    private func dequeueOrCreateTextOverlayView(
        clipId: UUID,
        descriptor: TextOverlayDescriptor,
        transform: TransformEffect
    ) -> EditorCanvasTextOverlayView {
        if let pooled = textOverlayViewPool.popLast() {
            pooled.applyConfiguration(clipID: clipId, descriptor: descriptor, transform: transform)
            return pooled
        }
        let overlay = EditorCanvasTextOverlayView(
            clipID: clipId,
            descriptor: descriptor,
            transform: transform
        )
        return overlay
    }

    private func retireTextOverlayViewToPool(_ view: EditorCanvasTextOverlayView) {
        view.removeFromSuperview()
        view.prepareForPooling()
        guard textOverlayViewPool.count < textOverlayPoolCapacity else { return }
        textOverlayViewPool.append(view)
    }

    /// Selection from timeline or canvas: yellow chrome and bring to front inside the host.
    func setActiveTextOverlayClipId(_ clipId: UUID?) {
        activeTextOverlayClipId = clipId
        refreshTextOverlaySelectionAppearance()
    }

    private func refreshTextOverlaySelectionAppearance() {
        for (id, view) in textOverlayViewsByClipId {
            let isActive = (id == activeTextOverlayClipId)
            view.setCanvasSelectionActive(isActive)
            view.setTransformGesturesEnabled(isActive)
        }
        if let id = activeTextOverlayClipId, let v = textOverlayViewsByClipId[id] {
            textOverlayHost.bringSubviewToFront(v)
        }
    }

    func updateTextOverlayContent(clipId: UUID, descriptor: TextOverlayDescriptor) {
        textOverlayViewsByClipId[clipId]?.update(descriptor: descriptor)
    }

    func updateTextOverlayTransform(clipId: UUID, transform: TransformEffect) {
        textOverlayViewsByClipId[clipId]?.update(transform: transform)
    }

    // MARK: - Actions

    @objc private func toggleTapped() {
        delegate?.renderView(self, didRequestToggleSizeWithExpanding: !isExpanded)
    }
}

// MARK: - EditorCanvasTextOverlayViewDelegate

extension EditorRenderView: EditorCanvasTextOverlayViewDelegate {

    func canvasTextOverlayView(_ view: EditorCanvasTextOverlayView, didUpdate transform: TransformEffect) {
        textOverlayDelegate?.editorRenderView(self, didUpdateTextOverlayClipId: view.clipID, transform: transform)
    }

    func canvasTextOverlayViewDidRequestActivation(_ view: EditorCanvasTextOverlayView) {
        setActiveTextOverlayClipId(view.clipID)
        textOverlayDelegate?.editorRenderView(self, didRequestActivateTextClipId: view.clipID)
    }
}
