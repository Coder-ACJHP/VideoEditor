//
// TextBottomSheetViewController
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Text overlay editor: compact sheet, text field growing from one line, font grid (2 columns),
//  4-column color swatches, alignment, background toggle. No style templates or AI.

import UIKit

@MainActor
final class TextBottomSheetViewController: UIViewController {

    private var descriptor: TextOverlayDescriptor
    /// Live canvas preview: main editor refreshes on every style change.
    private let onDescriptorChange: ((TextOverlayDescriptor) -> Void)?
    /// Cancel / dim tap: revert to the real overlay from the model (or clear draft state).
    private let onCancel: (() -> Void)?
    private let onComplete: (TextOverlayDescriptor) -> Void

    private enum Panel {
        case textEntry
        case fontPicker
        case colorPicker
        case alignmentPicker
    }

    private var activePanel: Panel = .textEntry {
        didSet { updateActivePanelUI() }
    }

    /// Full-screen dim + custom panel instead of `UISheetPresentationController`; entrance anim runs once.
    private var didStartEntranceAnimation = false
    /// Block keyboard until entrance finishes (avoids fighting `updateActivePanelUI`).
    private var didCompleteEntranceAnimation = false
    private var isDismissing = false

    // MARK: - Custom sheet chrome (solid, full width — no system sheet glass)

    private let dimmingControl: UIControl = {
        let c = UIControl()
        c.translatesAutoresizingMaskIntoConstraints = false
        c.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        c.accessibilityLabel = String(localized: "Dismiss")
        return c
    }()

    private let sheetPanel: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemGroupedBackground
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.clipsToBounds = true
        return v
    }()

    private let grabberView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.tertiaryLabel
        v.layer.cornerRadius = 2.5
        v.layer.cornerCurve = .continuous
        return v
    }()

    // MARK: Chrome (single background: systemGroupedBackground)

    private let topBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemGroupedBackground
        return v
    }()

    private lazy var cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(String(localized: "Cancel"), for: .normal)
        b.titleLabel?.font = .preferredFont(forTextStyle: .body)
        b.backgroundColor = .clear
        b.addAction(UIAction { [weak self] _ in self?.dismissForCancel() }, for: .touchUpInside)
        return b
    }()

    private lazy var doneButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(String(localized: "Done"), for: .normal)
        b.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        b.backgroundColor = .clear
        b.addAction(UIAction { [weak self] _ in self?.commitAndDismiss() }, for: .touchUpInside)
        return b
    }()

    private let toolbarStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.distribution = .equalSpacing
        s.alignment = .center
        s.spacing = 8
        s.backgroundColor = .systemGroupedBackground
        s.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        s.isLayoutMarginsRelativeArrangement = true
        return s
    }()

    private lazy var textModeButton = makeToolbarButton(symbolName: "square.and.pencil", accessibilityLabel: String(localized: "Text")) { [weak self] in
        self?.activePanel = .textEntry
    }
    private lazy var fontButton = makeToolbarButton(symbolName: "textformat.size", accessibilityLabel: String(localized: "Font")) { [weak self] in
        self?.view.endEditing(true)
        self?.activePanel = .fontPicker
    }
    private lazy var colorButton = makeToolbarButton(symbolName: "paintpalette.fill", accessibilityLabel: String(localized: "Color")) { [weak self] in
        self?.view.endEditing(true)
        self?.activePanel = .colorPicker
    }
    private lazy var alignButton = makeToolbarButton(symbolName: "text.alignleft", accessibilityLabel: String(localized: "Alignment")) { [weak self] in
        self?.view.endEditing(true)
        self?.activePanel = .alignmentPicker
    }
    private lazy var backgroundButton = makeToolbarButton(symbolName: "a.square.fill", accessibilityLabel: String(localized: "Background")) { [weak self] in
        self?.toggleBackground()
    }

    private let textView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = .preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.backgroundColor = .secondarySystemGroupedBackground
        tv.layer.cornerRadius = 10
        tv.layer.cornerCurve = .continuous
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        tv.textContainer.lineFragmentPadding = 0
        tv.keyboardDismissMode = .interactive
        tv.accessibilityIdentifier = "textSheet.body"
        tv.isScrollEnabled = false
        return tv
    }()

    private let accessoryScroll: UIScrollView = {
        let s = UIScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.alwaysBounceVertical = true
        s.keyboardDismissMode = .none
        s.backgroundColor = .clear
        return s
    }()

    private let accessoryContent: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 12
        s.backgroundColor = .clear
        return s
    }()

    private let fontStack = UIStackView()
    private let colorGridStack = UIStackView()
    private let alignmentStack = UIStackView()

    /// Vertical chain: toolbar → stack → safe area. Filler expands in text mode; hidden in accessory panels.
    private let bodyStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.alignment = .fill
        s.distribution = .fill
        s.spacing = 0
        return s
    }()

    private let bodyFiller: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }()

    /// Vertical font-size slider on the left edge of the dimming area.
    private let fontSizeSlider = FontSizeSliderView()

    private var textViewHeightConstraint: NSLayoutConstraint?

    private var fontOptionButtons: [UIButton] = []
    private var colorOptionViews: [(hex: String, view: UIButton)] = []
    private var alignmentOptionButtons: [(mode: TextOverlayTextAlignment, button: UIButton)] = []

    /// Text view grows up to this height; scrolling enables above it.
    private let textViewMaxHeight: CGFloat = 108

    private static let fontPostScriptNames: [String] = [
        "HelveticaNeue-Bold",
        "HelveticaNeue-Medium",
        "AvenirNext-Bold",
        "AvenirNext-DemiBold",
        "Georgia-Bold",
        "TimesNewRomanPSMT",
        "AmericanTypewriter",
        "Courier-Bold",
        "Palatino-Bold",
        "Noteworthy-Bold",
    ]

    private static let swatchHexes: [String] = [
        "#000000", "#1C1C1E", "#3A3A3C", "#48484A",
        "#FFFFFF", "#E5E5EA", "#FF3B30", "#FF9500",
        "#FFCC00", "#34C759", "#007AFF", "#5856D6",
    ]

    private static let defaultBackgroundHex = "#000000B3"

    // MARK: - Init

    init(
        initialDescriptor: TextOverlayDescriptor,
        onDescriptorChange: ((TextOverlayDescriptor) -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onComplete: @escaping (TextOverlayDescriptor) -> Void
    ) {
        self.descriptor = initialDescriptor
        self.onDescriptorChange = onDescriptorChange
        self.onCancel = onCancel
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildLayout()
        buildFontGrid()
        buildColorGrid()
        buildAlignmentRow()
        textView.text = descriptor.text
        textView.textAlignment = nsTextAlignment(descriptor.alignmentMode)
        syncToolbarSelection()
        refreshOptionSelectionOutlines()
        updateActivePanelUI()
        textView.delegate = self

        // Slider range and initial value match the 1080p-tall reference frame.
        fontSizeSlider.configure(
            minimumValue: 18,
            maximumValue: 96,
            initialValue: descriptor.fontSize
        )
        fontSizeSlider.onValueChanged = { [weak self] (newValue: CGFloat) in
            guard let self else { return }
            self.descriptor.fontSize = newValue
            self.emitLivePreview()
        }

        dimmingControl.addAction(UIAction { [weak self] _ in self?.dismissForCancel() }, for: .touchUpInside)
        // First frame: panel off-screen, dim hidden; `viewDidAppear` slides both in.
        dimmingControl.alpha = 0
        sheetPanel.transform = CGAffineTransform(translationX: 0, y: 900)
        emitLivePreview()
    }

    private func emitLivePreview() {
        onDescriptorChange?(descriptor)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTextViewHeight(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runEntranceAnimationIfNeeded()
    }

    // MARK: - Text height (starts one line tall; grows with newlines)

    private func singleLineTextViewHeight() -> CGFloat {
        let font = textView.font ?? UIFont.preferredFont(forTextStyle: .body)
        let line = ceil(font.lineHeight)
        return line + textView.textContainerInset.top + textView.textContainerInset.bottom
    }

    private func updateTextViewHeight(animated: Bool) {
        let w = textView.bounds.width
        guard w > 10 else { return }

        let textWidth = w - textView.textContainerInset.left - textView.textContainerInset.right
        let fitContent = textView.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
        let minH = singleLineTextViewHeight()
        let contentPlusInsets = fitContent + textView.textContainerInset.top + textView.textContainerInset.bottom
        let clamped = min(max(ceil(contentPlusInsets), minH), textViewMaxHeight)

        textViewHeightConstraint?.constant = clamped
        textView.isScrollEnabled = contentPlusInsets > textViewMaxHeight + 0.5

        let updates = { self.view.layoutIfNeeded() }
        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        view.addSubview(dimmingControl)
        dimmingControl.addSubview(fontSizeSlider)
        view.addSubview(sheetPanel)
        sheetPanel.addSubview(grabberView)
        sheetPanel.addSubview(topBar)
        topBar.addSubview(cancelButton)
        topBar.addSubview(doneButton)
        sheetPanel.addSubview(toolbarStack)
        sheetPanel.addSubview(bodyStack)
        bodyStack.addArrangedSubview(textView)
        bodyStack.addArrangedSubview(bodyFiller)
        bodyStack.addArrangedSubview(accessoryScroll)
        accessoryScroll.addSubview(accessoryContent)

        [textModeButton, fontButton, colorButton, alignButton, backgroundButton].forEach { toolbarStack.addArrangedSubview($0) }

        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        bodyFiller.setContentHuggingPriority(.defaultLow, for: .vertical)
        accessoryScroll.setContentHuggingPriority(.defaultLow, for: .vertical)

        let hConstraint = textView.heightAnchor.constraint(equalToConstant: singleLineTextViewHeight())
        textViewHeightConstraint = hConstraint

        NSLayoutConstraint.activate([
            dimmingControl.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingControl.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sheetPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetPanel.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),

            grabberView.topAnchor.constraint(equalTo: sheetPanel.topAnchor, constant: 8),
            grabberView.centerXAnchor.constraint(equalTo: sheetPanel.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 36),
            grabberView.heightAnchor.constraint(equalToConstant: 5),

            topBar.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: sheetPanel.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: sheetPanel.trailingAnchor),

            cancelButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            cancelButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            doneButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            doneButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            topBar.heightAnchor.constraint(equalToConstant: 48),

            toolbarStack.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            toolbarStack.leadingAnchor.constraint(equalTo: sheetPanel.leadingAnchor),
            toolbarStack.trailingAnchor.constraint(equalTo: sheetPanel.trailingAnchor),

            // Vertical font slider: fixed width on the leading side, just above the sheet panel.
            fontSizeSlider.bottomAnchor.constraint(equalTo: sheetPanel.topAnchor, constant: -20),
            fontSizeSlider.leadingAnchor.constraint(equalTo: dimmingControl.leadingAnchor),
            fontSizeSlider.heightAnchor.constraint(equalToConstant: 200),
            fontSizeSlider.widthAnchor.constraint(equalToConstant: 44),

            bodyStack.topAnchor.constraint(equalTo: toolbarStack.bottomAnchor, constant: 8),
            bodyStack.leadingAnchor.constraint(equalTo: sheetPanel.leadingAnchor, constant: 16),
            bodyStack.trailingAnchor.constraint(equalTo: sheetPanel.trailingAnchor, constant: -16),
            bodyStack.bottomAnchor.constraint(equalTo: sheetPanel.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            hConstraint,

            accessoryContent.topAnchor.constraint(equalTo: accessoryScroll.contentLayoutGuide.topAnchor),
            accessoryContent.leadingAnchor.constraint(equalTo: accessoryScroll.frameLayoutGuide.leadingAnchor, constant: 16),
            accessoryContent.trailingAnchor.constraint(equalTo: accessoryScroll.frameLayoutGuide.trailingAnchor, constant: -16),
            accessoryContent.bottomAnchor.constraint(equalTo: accessoryScroll.contentLayoutGuide.bottomAnchor),
            accessoryContent.widthAnchor.constraint(equalTo: accessoryScroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
    }

    private func runEntranceAnimationIfNeeded() {
        guard !didStartEntranceAnimation else { return }
        didStartEntranceAnimation = true
        view.layoutIfNeeded()
        let travel = sheetPanel.bounds.height + view.safeAreaInsets.bottom + 32
        sheetPanel.transform = CGAffineTransform(translationX: 0, y: max(travel, 320))
        dimmingControl.alpha = 0
        UIView.animate(
            withDuration: 0.38,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.4,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            self.dimmingControl.alpha = 1
            self.sheetPanel.transform = .identity
        } completion: { _ in
            self.didCompleteEntranceAnimation = true
            if self.activePanel == .textEntry {
                self.textView.becomeFirstResponder()
            }
        }
    }

    private func dismissForCancel() {
        guard !isDismissing else { return }
        isDismissing = true
        view.endEditing(true)
        onCancel?()
        animateSheetOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }

    private func animateSheetOut(completion: @escaping () -> Void) {
        view.layoutIfNeeded()
        let travel = sheetPanel.bounds.height + view.safeAreaInsets.bottom + 40
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseIn]) {
            self.dimmingControl.alpha = 0
            self.sheetPanel.transform = CGAffineTransform(translationX: 0, y: max(travel, 280))
        } completion: { _ in
            completion()
        }
    }

    private func buildFontGrid() {
        fontStack.axis = .vertical
        fontStack.spacing = 10
        fontStack.translatesAutoresizingMaskIntoConstraints = false
        fontOptionButtons.removeAll()

        var row: UIStackView?
        for (i, name) in Self.fontPostScriptNames.enumerated() {
            if i % 2 == 0 {
                row = UIStackView()
                row?.axis = .horizontal
                row?.spacing = 10
                row?.distribution = .fillEqually
                if let row { fontStack.addArrangedSubview(row) }
            }
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.layer.cornerRadius = 10
            btn.layer.cornerCurve = .continuous
            btn.backgroundColor = .secondarySystemGroupedBackground
            btn.titleLabel?.font = UIFont(name: name, size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
            btn.setTitle(displayName(forFont: name), for: .normal)
            btn.setTitleColor(.label, for: .normal)
            btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
            btn.tag = i
            btn.addAction(UIAction { [weak self, weak btn] _ in
                guard let self, let btn else { return }
                let ps = Self.fontPostScriptNames[btn.tag]
                self.descriptor.fontName = ps
                self.syncToolbarSelection()
                self.refreshOptionSelectionOutlines()
                self.emitLivePreview()
            }, for: .touchUpInside)
            row?.addArrangedSubview(btn)
            fontOptionButtons.append(btn)
        }
        accessoryContent.addArrangedSubview(fontStack)
    }

    private func displayName(forFont postScript: String) -> String {
        postScript.split(separator: "-").first.map(String.init) ?? postScript
    }

    private func buildColorGrid() {
        colorGridStack.axis = .vertical
        colorGridStack.spacing = 10
        colorOptionViews.removeAll()
        let columns = 4
        var rowStack: UIStackView?
        for (i, hex) in Self.swatchHexes.enumerated() {
            if i % columns == 0 {
                rowStack = UIStackView()
                rowStack?.axis = .horizontal
                rowStack?.spacing = 10
                rowStack?.distribution = .fillEqually
                if let rowStack { colorGridStack.addArrangedSubview(rowStack) }
            }
            let dot = UIButton(type: .system)
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 22
            dot.clipsToBounds = true
            dot.backgroundColor = UIColor(hexString: hex)
            dot.heightAnchor.constraint(equalToConstant: 44).isActive = true
            dot.accessibilityLabel = hex
            dot.addAction(UIAction { [weak self] _ in
                self?.descriptor.textColorHex = hex
                self?.syncToolbarSelection()
                self?.refreshOptionSelectionOutlines()
                self?.emitLivePreview()
            }, for: .touchUpInside)
            rowStack?.addArrangedSubview(dot)
            colorOptionViews.append((hex, dot))
        }
        accessoryContent.addArrangedSubview(colorGridStack)
    }

    private func buildAlignmentRow() {
        alignmentStack.axis = .vertical
        alignmentStack.spacing = 12
        alignmentOptionButtons.removeAll()
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually

        let pairs: [(TextOverlayTextAlignment, String)] = [
            (.natural, String(localized: "Natural")),
            (.left, String(localized: "Left")),
            (.center, String(localized: "Center")),
            (.right, String(localized: "Right")),
        ]
        for (mode, title) in pairs {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
            b.titleLabel?.adjustsFontForContentSizeCategory = true
            b.backgroundColor = .secondarySystemGroupedBackground
            b.layer.cornerRadius = 10
            b.layer.cornerCurve = .continuous
            b.addAction(UIAction { [weak self] _ in
                self?.descriptor.alignmentMode = mode
                self?.textView.textAlignment = Self.nsTextAlignmentStatic(mode)
                self?.syncToolbarSelection()
                self?.refreshOptionSelectionOutlines()
                self?.emitLivePreview()
            }, for: .touchUpInside)
            row.addArrangedSubview(b)
            alignmentOptionButtons.append((mode, b))
        }
        alignmentStack.addArrangedSubview(row)
        accessoryContent.addArrangedSubview(alignmentStack)
    }

    private func makeToolbarButton(symbolName: String, accessibilityLabel: String, handler: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        b.setImage(UIImage(systemName: symbolName, withConfiguration: config), for: .normal)
        b.accessibilityLabel = accessibilityLabel
        b.tintColor = .secondaryLabel
        b.backgroundColor = .clear
        b.addAction(UIAction { _ in handler() }, for: .touchUpInside)
        return b
    }

    // MARK: - Selection outlines

    private func refreshOptionSelectionOutlines() {
        let tint = UIColor.tintColor

        for (i, btn) in fontOptionButtons.enumerated() where i < Self.fontPostScriptNames.count {
            let name = Self.fontPostScriptNames[i]
            let selected = descriptor.fontName.caseInsensitiveCompare(name) == .orderedSame
            applySelectionOutline(to: btn, cornerRadius: 10, selected: selected, tint: tint)
        }

        for (hex, btn) in colorOptionViews {
            let selected = normalizedHex(descriptor.textColorHex) == normalizedHex(hex)
            let isLight = hex.uppercased() == "#FFFFFF" || hex.uppercased() == "#E5E5EA"
            applySelectionOutline(
                to: btn,
                cornerRadius: 22,
                selected: selected,
                tint: tint,
                unselectedHairlineForLightBackground: isLight
            )
        }

        for (mode, btn) in alignmentOptionButtons {
            let selected = descriptor.alignmentMode == mode
            applySelectionOutline(to: btn, cornerRadius: 10, selected: selected, tint: tint)
        }
    }

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

    private func normalizedHex(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "#", with: "")
    }

    private func updateActivePanelUI() {
        let isText = activePanel == .textEntry
        textView.isHidden = !isText
        accessoryScroll.isHidden = isText
        bodyFiller.isHidden = !isText

        if isText {
            if viewIfLoaded?.window != nil, didCompleteEntranceAnimation {
                textView.becomeFirstResponder()
            }
            updateTextViewHeight(animated: true)
        } else {
            view.endEditing(true)
        }

        fontStack.isHidden = activePanel != .fontPicker
        colorGridStack.isHidden = activePanel != .colorPicker
        alignmentStack.isHidden = activePanel != .alignmentPicker

        syncToolbarSelection()
    }

    private func syncToolbarSelection() {
        let secondary = UIColor.secondaryLabel
        let primary = UIColor.label
        textModeButton.tintColor = activePanel == .textEntry ? primary : secondary
        fontButton.tintColor = activePanel == .fontPicker ? primary : secondary
        colorButton.tintColor = activePanel == .colorPicker ? primary : secondary
        alignButton.tintColor = activePanel == .alignmentPicker ? primary : secondary
        let bgOn = descriptor.backgroundColorHex != nil
        backgroundButton.tintColor = bgOn ? primary : secondary
    }

    private func toggleBackground() {
        view.endEditing(true)
        if descriptor.backgroundColorHex != nil {
            descriptor.backgroundColorHex = nil
        } else {
            descriptor.backgroundColorHex = Self.defaultBackgroundHex
        }
        syncToolbarSelection()
        emitLivePreview()
    }

    private func commitAndDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        descriptor.text = textView.text ?? ""
        onComplete(descriptor)
        view.endEditing(true)
        animateSheetOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }

    private func nsTextAlignment(_ mode: TextOverlayTextAlignment) -> NSTextAlignment {
        Self.nsTextAlignmentStatic(mode)
    }

    private static func nsTextAlignmentStatic(_ mode: TextOverlayTextAlignment) -> NSTextAlignment {
        switch mode {
        case .natural: return .natural
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

}

// MARK: - UITextViewDelegate

extension TextBottomSheetViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        descriptor.text = textView.text ?? ""
        updateTextViewHeight(animated: true)
        emitLivePreview()
    }
}
