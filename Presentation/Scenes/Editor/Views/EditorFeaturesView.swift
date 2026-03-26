//
//  EditorFeaturesView.swift
//  VideoEditor
//
//  Bottom feature strip with two display states:
//
//  MAIN state (no clip selected):
//  ┌──────────────────────────────────────────────────────────┐
//  │ ─────────────────────── separator ──────────────────────│
//  │ [Audio] [Text] [Voice] [Sticker] [Filters] ...           │  ← scrollable
//  └──────────────────────────────────────────────────────────┘
//
//  SUB state (clip tapped in timeline):
//  ┌──────────────────────────────────────────────────────────┐
//  │ ─────────────────────── separator ──────────────────────│
//  │ [ ‹ ]  │  [Split] [Adjust] [Duplicate] [Delete]          │  ← scrollable
//  └──────────────────────────────────────────────────────────┘
//
//  Transition between states is a quick cross-dissolve.
//  The back button in the SUB state is fixed (outside the scroll view).
//

import UIKit

// MARK: - FeatureItem

struct FeatureItem: Equatable {
    let id: String
    let title: String
    let icon: UIImage?
    /// When `true`, the icon is tinted with `.systemYellow` to signal an active state.
    var isActive: Bool = false

    static func == (lhs: FeatureItem, rhs: FeatureItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - FeatureItem Static Libraries

extension FeatureItem {

    /// Items shown when no clip is selected (the default state).
    static var mainMenuItems: [FeatureItem] { [
        FeatureItem(id: "audio",    title: "Audio",    icon: UIImage(systemName: "music.note")),
        FeatureItem(id: "text",     title: "Text",     icon: UIImage(systemName: "textformat")),
        FeatureItem(id: "voice",    title: "Voice",    icon: UIImage(systemName: "mic")),
        FeatureItem(id: "sticker",  title: "Sticker",  icon: UIImage(systemName: "face.smiling")),
        FeatureItem(id: "filters",  title: "Filters",  icon: UIImage(systemName: "camera.filters")),
        FeatureItem(id: "adjust",   title: "Adjust",   icon: UIImage(systemName: "slider.horizontal.3")),
        FeatureItem(id: "speed",    title: "Speed",    icon: UIImage(systemName: "gauge")),
        FeatureItem(id: "effects",  title: "Effects",  icon: UIImage(systemName: "sparkles")),
        FeatureItem(id: "captions", title: "Captions", icon: UIImage(systemName: "captions.bubble")),
    ] }

    /// Items shown when a clip of the given track type is tapped in the timeline.
    static func subMenuItems(for trackType: MediaTrack.TrackType) -> [FeatureItem] {
        switch trackType {
        case .video:
            return [
                FeatureItem(id: "split",     title: "Split",     icon: UIImage(systemName: "scissors")),
                FeatureItem(id: "adjust",    title: "Adjust",    icon: UIImage(systemName: "slider.horizontal.3")),
                FeatureItem(id: "duplicate", title: "Duplicate", icon: UIImage(systemName: "doc.on.doc")),
                FeatureItem(id: "delete",    title: "Delete",    icon: UIImage(systemName: "trash")),
            ]
        case .audio:
            return [
                FeatureItem(id: "volume",    title: "Volume",    icon: UIImage(systemName: "speaker.wave.2")),
                FeatureItem(id: "fade",      title: "Fade",      icon: UIImage(systemName: "waveform")),
                FeatureItem(id: "duplicate", title: "Duplicate", icon: UIImage(systemName: "doc.on.doc")),
                FeatureItem(id: "delete",    title: "Delete",    icon: UIImage(systemName: "trash")),
            ]
        case .overlay:
            return [
                FeatureItem(id: "adjust",    title: "Adjust",    icon: UIImage(systemName: "slider.horizontal.3")),
                FeatureItem(id: "duplicate", title: "Duplicate", icon: UIImage(systemName: "doc.on.doc")),
                FeatureItem(id: "delete",    title: "Delete",    icon: UIImage(systemName: "trash")),
            ]
        }
    }
}

// MARK: - Delegate

protocol EditorFeaturesViewDelegate: AnyObject {
    /// Fired when the user taps any item in the main or sub menu.
    func featuresView(_ view: EditorFeaturesView, didSelectItem item: FeatureItem)
    /// Fired when the user taps the back button in the sub menu.
    func featuresViewDidTapBack(_ view: EditorFeaturesView)
}

// MARK: - EditorFeaturesView

final class EditorFeaturesView: UIView {

    // MARK: - Constants

    /// Fixed height for the interactive content area.
    /// Pin the view's bottomAnchor to safeAreaLayoutGuide.bottomAnchor in the parent.
    static let preferredHeight: CGFloat = 60

    // MARK: - Public

    weak var delegate: EditorFeaturesViewDelegate?
    private(set) var isShowingSubMenu = false

    // MARK: - State

    private var currentSubItems: [FeatureItem] = []

    // MARK: - Separator

    private lazy var separatorView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGray5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Main Panel

    private lazy var mainScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator   = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical = false
        sv.isDirectionalLockEnabled = true
        sv.contentInset = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var mainStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 0
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Sub Panel

    private lazy var subContainer: UIView = {
        let v = UIView()
        v.alpha = 0
        v.isUserInteractionEnabled = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var backButton: UIButton = {
        let symConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left", withConfiguration: symConfig)
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 10)
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        btn.accessibilityLabel = "Back to main menu"
        return btn
    }()

    private lazy var subScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator   = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical = false
        sv.isDirectionalLockEnabled = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var subStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 0
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        populate(stack: mainStack, with: FeatureItem.mainMenuItems)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private Setup

    private func setupView() {
        backgroundColor = .systemBackground
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(separatorView)
        setupMainPanel()
        setupSubPanel()
    }

    private func setupMainPanel() {
        mainScrollView.delegate = self
        addSubview(mainScrollView)
        mainScrollView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.heightAnchor.constraint(lessThanOrEqualToConstant: 0.5),
//            separatorView.heightAnchor.constraint(equalToConstant: 0.5),

            mainScrollView.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            mainStack.topAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: mainScrollView.contentLayoutGuide.trailingAnchor),
            mainStack.heightAnchor.constraint(equalTo: mainScrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    private func setupSubPanel() {
        subScrollView.delegate = self
        addSubview(subContainer)
        subContainer.addSubview(backButton)
        subContainer.addSubview(subScrollView)
        subScrollView.addSubview(subStack)

        NSLayoutConstraint.activate([
            subContainer.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
            subContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            subContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            subContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Back button: fixed to the left, vertically centered.
            backButton.leadingAnchor.constraint(equalTo: subContainer.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: subContainer.centerYAnchor),

            // Sub scroll view fills the remaining width to the right of the back button.
            subScrollView.topAnchor.constraint(equalTo: subContainer.topAnchor),
            subScrollView.leadingAnchor.constraint(equalTo: backButton.trailingAnchor),
            subScrollView.trailingAnchor.constraint(equalTo: subContainer.trailingAnchor),
            subScrollView.bottomAnchor.constraint(equalTo: subContainer.bottomAnchor),

            subStack.topAnchor.constraint(equalTo: subScrollView.contentLayoutGuide.topAnchor),
            subStack.bottomAnchor.constraint(equalTo: subScrollView.contentLayoutGuide.bottomAnchor),
            subStack.leadingAnchor.constraint(equalTo: subScrollView.contentLayoutGuide.leadingAnchor),
            subStack.trailingAnchor.constraint(equalTo: subScrollView.contentLayoutGuide.trailingAnchor),
            subStack.heightAnchor.constraint(equalTo: subScrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    // MARK: - Item Building

    private func populate(stack: UIStackView, with items: [FeatureItem]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        items.forEach { stack.addArrangedSubview(makeItemButton(for: $0)) }
    }

    private func makeItemButton(for item: FeatureItem) -> UIButton {
        let symConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        var config = UIButton.Configuration.plain()
        config.image = item.icon?.withConfiguration(symConfig)
        config.title = item.title
        config.imagePlacement = .top
        config.imagePadding = 8
        // Active items are tinted yellow (e.g. the currently applied filter or effect).
        config.baseForegroundColor = item.isActive ? .systemYellow : .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var updated = attrs
            updated.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            return updated
        }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 55).isActive = true
        // The item id is stored so `itemTapped` can look up the full FeatureItem.
        btn.accessibilityIdentifier = item.id
        btn.addTarget(self, action: #selector(itemTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - Public API

    /// Transitions back to the main feature menu.
    func showMainMenu(animated: Bool = true) {
        guard isShowingSubMenu else { return }
        isShowingSubMenu = false
        mainScrollView.isUserInteractionEnabled = true

        let transition: () -> Void = {
            self.mainScrollView.alpha = 1
            self.subContainer.alpha  = 0
        }
        let completion: (Bool) -> Void = { _ in
            self.subContainer.isUserInteractionEnabled = false
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0,
                           options: .curveEaseOut,
                           animations: transition,
                           completion: completion)
        } else {
            transition(); completion(true)
        }
    }

    /// Transitions to a context-sensitive sub menu.
    /// - Parameters:
    ///   - items: Build these with `FeatureItem.subMenuItems(for:)`.
    ///   - animated: Set to `false` when updating without a visible transition.
    func showSubMenu(items: [FeatureItem], animated: Bool = true) {
        isShowingSubMenu = true
        currentSubItems  = items
        populate(stack: subStack, with: items)
        subScrollView.contentOffset = .zero
        subContainer.isUserInteractionEnabled = true
        mainScrollView.isUserInteractionEnabled = false

        let transition: () -> Void = {
            self.subContainer.alpha  = 1
            self.mainScrollView.alpha = 0
        }
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut, animations: transition)
        } else {
            transition()
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        delegate?.featuresViewDidTapBack(self)
    }

    @objc private func itemTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        // Search the list that corresponds to the currently visible panel.
        let pool = isShowingSubMenu ? currentSubItems : FeatureItem.mainMenuItems
        guard let item = pool.first(where: { $0.id == id }) else { return }
        delegate?.featuresView(self, didSelectItem: item)
    }
}

// MARK: - UIScrollViewDelegate

extension EditorFeaturesView: UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Hard-lock vertical movement so this strip behaves as a pure horizontal rail.
        if scrollView.contentOffset.y != 0 {
            scrollView.contentOffset.y = 0
        }
    }
}
