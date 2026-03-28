//
//  AudioBottomSheetViewController.swift
//  VideoEditor
//
//  Instagram Reels–style audio browser: search, Import, category tabs, track list,
//  and a floating confirm bar when a track is selected.
//

import UIKit

@MainActor
final class AudioBottomSheetViewController: UIViewController {

    private weak var router: RouterDelegate?
    /// Called when the user taps the floating confirm control; run timeline updates in this closure, then the sheet dismisses.
    private let onAudioConfirmed: (@MainActor (AudioBrowseItem) -> Void)?

    private var selectedTab: AudioBrowseTab = .forYou {
        didSet { updateTabSelection(animated: true) }
    }

    private var allItems: [AudioBrowseItem] = []
    private var filteredItems: [AudioBrowseItem] = []
    private var selectedItem: AudioBrowseItem?
    private var isPreviewPlaying = false

    // MARK: Chrome

    private let searchField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.backgroundColor = AudioSheetPalette.elevated
        tf.textColor = AudioSheetPalette.primaryText
        tf.font = UIFont.preferredFont(forTextStyle: .body)
        tf.adjustsFontForContentSizeCategory = true
        tf.layer.cornerRadius = 10
        tf.layer.cornerCurve = .continuous
        tf.clipsToBounds = true
        tf.returnKeyType = .search
        tf.clearButtonMode = .whileEditing
        tf.attributedPlaceholder = NSAttributedString(
            string: String(localized: "Search audio"),
            attributes: [
                .foregroundColor: AudioSheetPalette.tertiaryText,
                .font: UIFont.preferredFont(forTextStyle: .body),
            ]
        )
        tf.accessibilityIdentifier = "audioSheet.search"
        return tf
    }()

    private lazy var importButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AudioSheetPalette.elevated
        config.baseForegroundColor = AudioSheetPalette.primaryText
        config.cornerStyle = .fixed
        config.background.cornerRadius = 10
        config.image = UIImage(systemName: "music.note")
        config.title = String(localized: "Import")
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var o = incoming
            o.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return o
        }
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        b.accessibilityIdentifier = "audioSheet.import"
        return b
    }()

    private let tabScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return sv
    }()

    private let tabStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.spacing = 22
        s.alignment = .bottom
        return s
    }()

    private var tabButtons: [UIButton] = []
    private let tabIndicator: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = AudioSheetPalette.primaryText
        v.layer.cornerRadius = 1
        return v
    }()

    private var tabIndicatorConstraints: [NSLayoutConstraint] = []

    private lazy var tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.backgroundColor = .clear
        t.separatorStyle = .none
        t.rowHeight = UITableView.automaticDimension
        t.estimatedRowHeight = 76
        t.keyboardDismissMode = .onDrag
        t.register(AudioTrackTableViewCell.self, forCellReuseIdentifier: AudioTrackTableViewCell.reuseId)
        t.dataSource = self
        t.delegate = self
        t.accessibilityIdentifier = "audioSheet.table"
        return t
    }()

    // MARK: Floating bar

    private let floatingBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = AudioSheetPalette.floatingBar
        v.layer.cornerRadius = 28
        v.layer.cornerCurve = .continuous
        v.isHidden = true
        v.alpha = 0
        return v
    }()

    private let floatingThumb: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 22
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()

    private let floatingThumbIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white.withAlphaComponent(0.9)
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iv.image = UIImage(systemName: "music.note")
        return iv
    }()

    private let floatingTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont.preferredFont(forTextStyle: .subheadline).addingSymbolicTraits(.traitBold)
        l.textColor = AudioSheetPalette.primaryText
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let floatingArtistLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont.preferredFont(forTextStyle: .caption1)
        l.textColor = AudioSheetPalette.secondaryText
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private lazy var pauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.tintColor = AudioSheetPalette.primaryText
        b.addTarget(self, action: #selector(togglePreviewPlayback), for: .touchUpInside)
        b.accessibilityLabel = String(localized: "Play or pause preview")
        return b
    }()

    private lazy var confirmButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .white
        b.tintColor = .black
        let sym = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        b.setImage(UIImage(systemName: "arrow.right", withConfiguration: sym), for: .normal)
        b.layer.cornerRadius = 22
        b.layer.cornerCurve = .continuous
        b.addTarget(self, action: #selector(confirmSelectionTapped), for: .touchUpInside)
        b.accessibilityIdentifier = "audioSheet.confirm"
        b.accessibilityLabel = String(localized: "Use selected audio")
        return b
    }()

    private var floatingBarBottomConstraint: NSLayoutConstraint?

    init(router: RouterDelegate, onAudioConfirmed: (@MainActor (AudioBrowseItem) -> Void)? = nil) {
        self.router = router
        self.onAudioConfirmed = onAudioConfirmed
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = AudioSheetPalette.background
        view.accessibilityIdentifier = "audioSheet.root"

        setupSearchRow()
        setupTabs()
        setupTable()
        setupFloatingBar()

        loadPlaceholderCatalog()
        applyFilters()
        updateTabSelection(animated: false)
        updatePauseButtonImage()

        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
    }

    // MARK: Setup

    private func setupSearchRow() {
        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = AudioSheetPalette.tertiaryText
        searchIcon.contentMode = .scaleAspectFit
        let iconSize: CGFloat = 20
        let left = UIView(frame: CGRect(x: 0, y: 0, width: iconSize + 24, height: 36))
        searchIcon.frame = CGRect(x: 12, y: 8, width: iconSize, height: iconSize)
        left.addSubview(searchIcon)
        searchField.leftView = left
        searchField.leftViewMode = .always

        view.addSubview(searchField)
        view.addSubview(importButton)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20.resp),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.heightAnchor.constraint(equalToConstant: 44),

            importButton.leadingAnchor.constraint(equalTo: searchField.trailingAnchor, constant: 10),
            importButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            importButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            importButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupTabs() {
        view.addSubview(tabScrollView)
        tabScrollView.addSubview(tabStack)

        for tab in AudioBrowseTab.allCases {
            let b = UIButton(type: .system)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.tag = tab.rawValue
            b.setTitle(tab.title, for: .normal)
            b.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
            b.titleLabel?.adjustsFontForContentSizeCategory = true
            b.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabButtons.append(b)
            tabStack.addArrangedSubview(b)
        }

        tabScrollView.addSubview(tabIndicator)

        NSLayoutConstraint.activate([
            tabScrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 14),
            tabScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabScrollView.heightAnchor.constraint(equalToConstant: 40),

            tabStack.topAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.topAnchor),
            tabStack.leadingAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.leadingAnchor),
            tabStack.trailingAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.trailingAnchor),
            tabStack.bottomAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.bottomAnchor, constant: -6),
            tabStack.heightAnchor.constraint(equalTo: tabScrollView.frameLayoutGuide.heightAnchor, constant: -6),
        ])
    }

    private func setupTable() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: tabScrollView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupFloatingBar() {
        view.addSubview(floatingBar)
        floatingBar.addSubview(floatingThumb)
        floatingThumb.addSubview(floatingThumbIcon)
        floatingBar.addSubview(floatingTitleLabel)
        floatingBar.addSubview(floatingArtistLabel)
        floatingBar.addSubview(pauseButton)
        floatingBar.addSubview(confirmButton)

        let bottom = floatingBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        floatingBarBottomConstraint = bottom

        NSLayoutConstraint.activate([
            floatingBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            floatingBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottom,
            floatingBar.heightAnchor.constraint(equalToConstant: 56),

            floatingThumb.leadingAnchor.constraint(equalTo: floatingBar.leadingAnchor, constant: 8),
            floatingThumb.centerYAnchor.constraint(equalTo: floatingBar.centerYAnchor),
            floatingThumb.widthAnchor.constraint(equalToConstant: 44),
            floatingThumb.heightAnchor.constraint(equalToConstant: 44),

            floatingThumbIcon.centerXAnchor.constraint(equalTo: floatingThumb.centerXAnchor),
            floatingThumbIcon.centerYAnchor.constraint(equalTo: floatingThumb.centerYAnchor),

            floatingTitleLabel.leadingAnchor.constraint(equalTo: floatingThumb.trailingAnchor, constant: 10),
            floatingTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pauseButton.leadingAnchor, constant: -8),
            floatingTitleLabel.topAnchor.constraint(equalTo: floatingBar.topAnchor, constant: 10),

            floatingArtistLabel.leadingAnchor.constraint(equalTo: floatingTitleLabel.leadingAnchor),
            floatingArtistLabel.trailingAnchor.constraint(equalTo: floatingTitleLabel.trailingAnchor),
            floatingArtistLabel.topAnchor.constraint(equalTo: floatingTitleLabel.bottomAnchor, constant: 0),

            pauseButton.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -4),
            pauseButton.centerYAnchor.constraint(equalTo: floatingBar.centerYAnchor),
            pauseButton.widthAnchor.constraint(equalToConstant: 44),
            pauseButton.heightAnchor.constraint(equalToConstant: 44),

            confirmButton.trailingAnchor.constraint(equalTo: floatingBar.trailingAnchor, constant: -8),
            confirmButton.centerYAnchor.constraint(equalTo: floatingBar.centerYAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 44),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: Data

    private func loadPlaceholderCatalog() {
        let locator = BundledTestMediaLocator()
        let mockItemUrl = locator.url(resource: "Reflection", extension: "mp3")
        allItems = [
            AudioBrowseItem(id: "1", title: "What Was That", artist: "Lorde", durationLabel: "3:30", useCountLabel: "2.8K reels", thumbTint: UIColor.systemPurple.withAlphaComponent(0.55), url: mockItemUrl),
            AudioBrowseItem(id: "2", title: "Green Light", artist: "Lorde", durationLabel: "3:59", useCountLabel: "12K reels", thumbTint: UIColor.systemTeal.withAlphaComponent(0.5), url: mockItemUrl),
            AudioBrowseItem(id: "3", title: "Royals", artist: "Lorde", durationLabel: "3:10", useCountLabel: "890K reels", thumbTint: UIColor.systemOrange.withAlphaComponent(0.45), url: mockItemUrl),
            AudioBrowseItem(id: "4", title: "Team", artist: "Lorde", durationLabel: "3:13", useCountLabel: "45K reels", thumbTint: UIColor.systemPink.withAlphaComponent(0.45), url: mockItemUrl),
            AudioBrowseItem(id: "5", title: "Solar Power", artist: "Lorde", durationLabel: "3:12", useCountLabel: "8.1K reels", thumbTint: UIColor.systemYellow.withAlphaComponent(0.35), url: mockItemUrl),
        ]
    }

    private func applyFilters() {
        let base = allItems
        let q = (searchField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            filteredItems = base
        } else {
            filteredItems = base.filter {
                $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
            }
        }
        tableView.reloadData()
    }

    // MARK: Tabs

    private func updateTabSelection(animated: Bool) {
        for b in tabButtons {
            let isOn = b.tag == selectedTab.rawValue
            b.setTitleColor(isOn ? AudioSheetPalette.primaryText : AudioSheetPalette.tabInactive, for: .normal)
        }
        guard let btn = tabButtons.first(where: { $0.tag == selectedTab.rawValue }) else { return }
        NSLayoutConstraint.deactivate(tabIndicatorConstraints)
        tabIndicatorConstraints = [
            tabIndicator.leadingAnchor.constraint(equalTo: btn.leadingAnchor),
            tabIndicator.trailingAnchor.constraint(equalTo: btn.trailingAnchor),
            tabIndicator.heightAnchor.constraint(equalToConstant: 2),
            tabIndicator.bottomAnchor.constraint(equalTo: tabStack.bottomAnchor, constant: 4),
        ]
        let apply = {
            NSLayoutConstraint.activate(self.tabIndicatorConstraints)
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: apply)
        } else {
            apply()
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        guard let tab = AudioBrowseTab(rawValue: sender.tag) else { return }
        selectedTab = tab
        applyFilters()
    }

    // MARK: Floating bar

    private func showFloatingBar(for item: AudioBrowseItem, animated: Bool) {
        selectedItem = item
        floatingTitleLabel.text = item.title
        floatingArtistLabel.text = item.artist
        floatingThumb.backgroundColor = item.thumbTint
        isPreviewPlaying = false
        updatePauseButtonImage()

        let show = {
            self.floatingBar.isHidden = false
            self.floatingBar.alpha = 1
            self.tableView.contentInset.bottom = 88
            self.tableView.verticalScrollIndicatorInsets.bottom = 88
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: show)
        } else {
            show()
        }
    }

    private func hideFloatingBar() {
        selectedItem = nil
        UIView.animate(withDuration: 0.2, animations: {
            self.floatingBar.alpha = 0
        }, completion: { _ in
            self.floatingBar.isHidden = true
            self.tableView.contentInset.bottom = 0
            self.tableView.verticalScrollIndicatorInsets.bottom = 0
        })
    }

    private func updatePauseButtonImage() {
        let name = isPreviewPlaying ? "pause.fill" : "play.fill"
        let sym = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        pauseButton.setImage(UIImage(systemName: name, withConfiguration: sym), for: .normal)
    }

    @objc private func togglePreviewPlayback() {
        isPreviewPlaying.toggle()
        updatePauseButtonImage()
    }

    @objc private func confirmSelectionTapped() {
        guard let item = selectedItem else { return }
        onAudioConfirmed?(item)
        dismiss(animated: true)
    }

    @objc private func importTapped() {
        // Hook: PHPicker / document import when the use case is wired.
    }

    @objc private func searchTextChanged() {
        applyFilters()
    }
}

// MARK: - UITableView

extension AudioBottomSheetViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AudioTrackTableViewCell.reuseId, for: indexPath) as? AudioTrackTableViewCell else {
            return UITableViewCell()
        }
        let item = filteredItems[indexPath.row]
        cell.configure(with: item)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = filteredItems[indexPath.row]
        showFloatingBar(for: item, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension AudioBottomSheetViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
