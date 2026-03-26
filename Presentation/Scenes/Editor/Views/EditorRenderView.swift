//
//  EditorRenderView.swift
//  VideoEditor
//
//  Preview / playback area for the editing canvas.
//  Contains a media canvas that maintains its aspect ratio inside the view,
//  and a toggle button that lets the parent VC animate between a compact
//  (~40 % of screen) and an expanded (~65 % of screen) height.
//

import UIKit

// MARK: - Delegate

protocol EditorRenderViewDelegate: AnyObject {
    /// Fired when the user taps the expand/collapse chevron button.
    /// - Parameter isExpanding: `true` when the view should grow, `false` when it should shrink.
    func renderView(_ renderView: EditorRenderView, didRequestToggleSizeWithExpanding isExpanding: Bool)
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

    /// Read-only expansion state; mutated via `setExpanded(_:)`.
    private(set) var isExpanded = false

    /// The compositing surface. Callers (e.g. AVPlayerLayer, CALayer overlays)
    /// should attach directly to this view's layer.
    let canvas: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

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
        addSubview(toggleButton)

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

    // MARK: - Actions

    @objc private func toggleTapped() {
        delegate?.renderView(self, didRequestToggleSizeWithExpanding: !isExpanded)
    }
}
