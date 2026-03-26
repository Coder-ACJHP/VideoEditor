//
//  EditorNavigationBar.swift
//  VideoEditor
//
//  Custom navigation bar for the video editor canvas screen.
//  Replaces UINavigationBar to allow full-height customization and
//  pixel-perfect layout control independent of UINavigationController.
//

import UIKit

// MARK: - Delegate

protocol EditorNavigationBarDelegate: AnyObject {
    /// Called when the user taps the close (✕) button.
    func editorNavBarDidTapClose(_ navBar: EditorNavigationBar)
    /// Called when the user taps the project title / chevron — use for rename / options sheet.
    func editorNavBarDidTapTitle(_ navBar: EditorNavigationBar)
    /// Called when the user taps the "Next" action button.
    func editorNavBarDidTapNext(_ navBar: EditorNavigationBar)
}

// MARK: - EditorNavigationBar

/// A custom navigation bar designed for the video editor canvas.
///
/// Layout:
/// ```
/// [ ✕ ]  [ Project Name ⌄ ]          [ 9:16 ]  [ Next › ]
/// ──────────────────────── separator ────────────────────────
/// ```
///
/// System adaptive colors are used throughout so the component responds
/// correctly to both light and dark mode without any extra work.
final class EditorNavigationBar: UIView {

    // MARK: - Public

    weak var delegate: EditorNavigationBarDelegate?

    // MARK: - Left Side

    private lazy var closeButton: UIButton = {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark", withConfiguration: symbolConfig)
        config.baseForegroundColor = .label
        // Extra tap target padding without changing visual size.
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 6)
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        btn.accessibilityLabel = "Close editor"
        return btn
    }()

    private lazy var titleButton: UIButton = {
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            return attrs
        }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(titleTapped), for: .touchUpInside)
        btn.accessibilityLabel = "Project options"
        return btn
    }()

    private lazy var leftStack: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [closeButton, titleButton])
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 2
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Right Side

    private lazy var resolutionLabel: UILabel = {
        let lbl = UILabel()
        // Monospaced digits keep the label width stable as the ratio text changes.
        lbl.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.accessibilityLabel = "Canvas aspect ratio"
        return lbl
    }()

    private lazy var nextButton: UIButton = {
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        var config = UIButton.Configuration.filled()
        config.title = "Next"
        config.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        config.imagePlacement = .trailing
        config.imagePadding = 4
        // Inverted semantics: background = primary text color, foreground = background color.
        // Dark mode  → white pill with black text.
        // Light mode → black pill with white text.
        config.baseBackgroundColor = .label
        config.baseForegroundColor = .systemBackground
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attrs = incoming
            attrs.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            return attrs
        }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        btn.accessibilityLabel = "Proceed to export"
        return btn
    }()

    private lazy var rightStack: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [resolutionLabel, nextButton])
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 12
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Bottom Separator

    private lazy var separatorView: UIView = {
        let v = UIView()
        // .separator is a semantic color that respects dark / light mode automatically.
        v.backgroundColor = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

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
        backgroundColor = .systemBackground
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftStack)
        addSubview(rightStack)
        addSubview(separatorView)

        NSLayoutConstraint.activate([
            // Left cluster — flush to leading edge with a small inset.
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Right cluster — flush to trailing edge.
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Prevent horizontal overlap on narrow devices / small font sizes.
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),

            // Hair-line separator at the very bottom of the bar.
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    // MARK: - Configuration

    /// Populates the bar with project-specific data.
    /// - Parameters:
    ///   - projectName: Display name shown in the title button.
    ///   - aspectRatio: Human-readable ratio string, e.g. `"9:16"` or `"1:1"`.
    func configure(projectName: String, aspectRatio: String) {
        var btnConfig = titleButton.configuration
        btnConfig?.title = projectName
        titleButton.configuration = btnConfig
        resolutionLabel.text = aspectRatio
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        delegate?.editorNavBarDidTapClose(self)
    }

    @objc private func titleTapped() {
        delegate?.editorNavBarDidTapTitle(self)
    }

    @objc private func nextTapped() {
        delegate?.editorNavBarDidTapNext(self)
    }
}
