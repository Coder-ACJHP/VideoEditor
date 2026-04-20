//
// CanvasBackgroundBottomSheetViewController
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  System sheet: Solid vs Gradient tabs, live-updates composition background via callback.
//

import UIKit

@MainActor
final class CanvasBackgroundBottomSheetViewController: UIViewController {

    private typealias SwatchLayout = TimelineConfiguration.CanvasBackgroundSwatchLayout

    private var settings: CanvasBackgroundSettings
    private let onSettingsChange: (CanvasBackgroundSettings) -> Void

    private enum Tab: Int {
        case solid = 0
        case gradient = 1
    }

    private var activeTab: Tab = .solid {
        didSet { updateTabVisibility() }
    }

    private lazy var doneButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(String(localized: "Done"), for: .normal)
        b.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        b.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        b.accessibilityIdentifier = "canvasSheet.done"
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .preferredFont(forTextStyle: .title3)
        l.text = String(localized: "Canvas background")
        l.textAlignment = .center
        l.numberOfLines = 2
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private lazy var tabSwitch: UISegmentedControl = {
        let s = UISegmentedControl(items: [
            String(localized: "Solid"),
            String(localized: "Gradient")
        ])
        s.translatesAutoresizingMaskIntoConstraints = false
        s.selectedSegmentIndex = 0
        s.accessibilityIdentifier = "canvasSheet.segment"
        s.addAction(UIAction { [weak self] a in
            guard let self, let c = a.sender as? UISegmentedControl else { return }
            self.tabChanged(to: Tab(rawValue: c.selectedSegmentIndex) ?? .solid)
        }, for: .valueChanged)
        return s
    }()

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alwaysBounceVertical = true
        v.keyboardDismissMode = .onDrag
        return v
    }()

    private let scrollContentStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 0
        s.alignment = .fill
        return s
    }()

    private let solidStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 12
        s.alignment = .fill
        return s
    }()

    private let gradientStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 12
        s.alignment = .fill
        return s
    }()

    private var solidColorButtons: [(hex: String?, button: UIButton)] = []
    private var gradientPresetControls: [(preset: CanvasGradientPreset, control: GradientSwatchControl)] = []

    init(initial: CanvasBackgroundSettings, onSettingsChange: @escaping (CanvasBackgroundSettings) -> Void) {
        self.settings = initial
        self.onSettingsChange = onSettingsChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(titleLabel)
        view.addSubview(doneButton)
        view.addSubview(tabSwitch)
        view.addSubview(scrollView)

        scrollView.addSubview(scrollContentStack)
        scrollContentStack.addArrangedSubview(solidStack)
        scrollContentStack.addArrangedSubview(gradientStack)

        buildSolidGrid()
        buildGradientGrid()

        NSLayoutConstraint.activate([
            doneButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            titleLabel.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -8),

            tabSwitch.topAnchor.constraint(equalTo: doneButton.bottomAnchor, constant: 16),
            tabSwitch.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: tabSwitch.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            scrollContentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        scrollContentStack.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        scrollContentStack.isLayoutMarginsRelativeArrangement = true

        syncUIFromSettings()
    }

    private func tabChanged(to tab: Tab) {
        activeTab = tab
        switch tab {
        case .solid:
            if settings.style != .solid {
                let hex = trimmedSolidHex(settings.primaryHex)
                settings = CanvasBackgroundSettings(style: .solid, primaryHex: hex, secondaryHex: nil)
                onSettingsChange(settings)
            }
        case .gradient:
            if settings.style != .linearGradient {
                let preset = CanvasGradientPreset.catalog[0]
                settings = CanvasBackgroundSettings(
                    style: .linearGradient,
                    primaryHex: preset.startHex,
                    secondaryHex: preset.endHex
                )
                onSettingsChange(settings)
            }
        }
        refreshSelectionChrome()
    }

    private func updateTabVisibility() {
        solidStack.isHidden = activeTab != .solid
        gradientStack.isHidden = activeTab != .gradient
    }

    private func syncUIFromSettings() {
        switch settings.style {
        case .solid:
            activeTab = .solid
            tabSwitch.selectedSegmentIndex = Tab.solid.rawValue
        case .linearGradient:
            activeTab = .gradient
            tabSwitch.selectedSegmentIndex = Tab.gradient.rawValue
        }
        updateTabVisibility()
        refreshSelectionChrome()
    }

    private func buildSolidGrid() {
        let cols = 4
        let swatches: [(String?, String)] = [
            (nil, String(localized: "Black")),
            ("#FFFFFF", String(localized: "White")),
            ("#8E8E93", String(localized: "Gray")),
            ("#1A1A2E", String(localized: "Ink")),
            ("#E63946", String(localized: "Red")),
            ("#F4A261", String(localized: "Orange")),
            ("#2A9D8F", String(localized: "Teal")),
            ("#264653", String(localized: "Petrol")),
            ("#415A77", String(localized: "Steel")),
            ("#7209B7", String(localized: "Purple")),
            ("#FFD166", String(localized: "Gold")),
            ("#06D6A0", String(localized: "Mint"))
        ]

        var rowStack: UIStackView?
        for (i, item) in swatches.enumerated() {
            if i % cols == 0 {
                rowStack = UIStackView()
                rowStack?.axis = .horizontal
                rowStack?.spacing = 10
                rowStack?.distribution = .fillEqually
                rowStack?.alignment = .center
                if let r = rowStack { solidStack.addArrangedSubview(r) }
            }
            let btn = makeSolidSwatch(hex: item.0, accessibilityLabel: item.1)
            solidColorButtons.append((item.0, btn))
            rowStack?.addArrangedSubview(btn)
            btn.heightAnchor.constraint(equalTo: btn.widthAnchor, multiplier: 1).isActive = true
        }
    }

    private func makeSolidSwatch(hex: String?, accessibilityLabel: String) -> UIButton {
        let dot = UIButton(type: .system)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = SwatchLayout.cornerRadius
        dot.layer.cornerCurve = .continuous
        dot.clipsToBounds = true
        if let h = hex {
            dot.backgroundColor = UIColor(hexString: h)
        } else {
            dot.backgroundColor = .black
        }
        dot.heightAnchor.constraint(equalToConstant: SwatchLayout.side).isActive = true
        dot.accessibilityLabel = accessibilityLabel
        dot.addAction(UIAction { [weak self] _ in
            self?.selectSolid(hex: hex)
        }, for: .touchUpInside)
        return dot
    }

    private func selectSolid(hex: String?) {
        if activeTab != .solid {
            tabSwitch.selectedSegmentIndex = Tab.solid.rawValue
            activeTab = .solid
            updateTabVisibility()
        }
        settings = CanvasBackgroundSettings(style: .solid, primaryHex: trimmedSolidHex(hex), secondaryHex: nil)
        onSettingsChange(settings)
        refreshSelectionChrome()
    }

    private func buildGradientGrid() {
        let cols = 4
        let presets = CanvasGradientPreset.catalog
        var rowStack: UIStackView?
        for (i, preset) in presets.enumerated() {
            if i % cols == 0 {
                rowStack = UIStackView()
                rowStack?.axis = .horizontal
                rowStack?.spacing = 10
                rowStack?.distribution = .fillEqually
                rowStack?.alignment = .center
                if let r = rowStack { gradientStack.addArrangedSubview(r) }
            }
            let c = GradientSwatchControl(preset: preset)
            c.translatesAutoresizingMaskIntoConstraints = false
            c.accessibilityLabel = preset.localizedTitle
            c.addAction(UIAction { [weak self] _ in
                self?.selectGradient(preset)
            }, for: .touchUpInside)
            c.heightAnchor.constraint(equalToConstant: SwatchLayout.side).isActive = true
            rowStack?.addArrangedSubview(c)
            c.heightAnchor.constraint(equalTo: c.widthAnchor, multiplier: 1).isActive = true
            gradientPresetControls.append((preset, c))
        }
    }

    private func selectGradient(_ preset: CanvasGradientPreset) {
        if activeTab != .gradient {
            tabSwitch.selectedSegmentIndex = Tab.gradient.rawValue
            activeTab = .gradient
            updateTabVisibility()
        }
        settings = CanvasBackgroundSettings(
            style: .linearGradient,
            primaryHex: preset.startHex,
            secondaryHex: preset.endHex
        )
        onSettingsChange(settings)
        refreshSelectionChrome()
    }

    private func refreshSelectionChrome() {
        let tint = UIColor.tintColor
        for (hex, btn) in solidColorButtons {
            let selected = settings.style == .solid && solidHexKey(hex) == solidHexKey(settings.primaryHex)
            let isLight = hex.map { h in
                let u = h.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                return u == "#FFFFFF" || u == "#E5E5EA"
            } ?? false
            applySelectionOutline(
                to: btn,
                cornerRadius: SwatchLayout.cornerRadius,
                selected: selected,
                tint: tint,
                unselectedHairlineForLightBackground: isLight
            )
        }
        for (preset, control) in gradientPresetControls {
            let selected = settings.style == .linearGradient
                && solidHexKey(preset.startHex) == solidHexKey(settings.primaryHex)
                && solidHexKey(preset.endHex) == solidHexKey(settings.secondaryHex)
            control.setSelected(selected, tint: tint)
        }
    }

    private func trimmedSolidHex(_ hex: String?) -> String? {
        guard let raw = hex else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Normalized comparison key (`#` stripped, uppercased); `nil` / empty → `""` for black.
    private func solidHexKey(_ hex: String?) -> String {
        guard let h = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty else {
            return ""
        }
        return h.uppercased().replacingOccurrences(of: "#", with: "")
    }

    /// Matches `TextBottomSheetViewController` color / alignment chip selection chrome.
    private func applySelectionOutline(
        to view: UIView,
        cornerRadius: CGFloat,
        selected: Bool,
        tint: UIColor,
        unselectedHairlineForLightBackground: Bool = false
    ) {
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        if selected {
            view.layer.borderWidth = 2.5
            view.layer.borderColor = tint.cgColor
        } else if unselectedHairlineForLightBackground {
            view.layer.borderWidth = 1
            view.layer.borderColor = UIColor.separator.cgColor
        } else {
            view.layer.borderWidth = 0
            view.layer.borderColor = nil
        }
    }
}

// MARK: - Gradient swatch (same footprint as solid color dots)

private final class GradientSwatchControl: UIControl {

    private let preset: CanvasGradientPreset
    private let gradientLayer = CAGradientLayer()

    init(preset: CanvasGradientPreset) {
        self.preset = preset
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.cornerRadius = TimelineConfiguration.CanvasBackgroundSwatchLayout.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        gradientLayer.colors = [
            UIColor(hexString: preset.startHex).cgColor,
            UIColor(hexString: preset.endHex).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.cornerRadius = layer.cornerRadius
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
    }

    func setSelected(_ selected: Bool, tint: UIColor = .tintColor) {
        if selected {
            layer.borderWidth = 2.5
            layer.borderColor = tint.cgColor
        } else {
            layer.borderWidth = 0
            layer.borderColor = nil
        }
    }
}
