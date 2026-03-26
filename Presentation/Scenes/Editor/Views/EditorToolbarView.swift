//
//  EditorToolbarView.swift
//  VideoEditor
//
//  Playback control strip sitting directly below the render view.
//
//  Layout:
//  ┌──────────────────────────────────────────────────────┐
//  │ ─────────────── 0.5 pt separator ─────────────────── │
//  │ [▶]      00:02          [↩]  [↪]                     │
//  │           00:06                                      │
//  └──────────────────────────────────────────────────────┘
//

import UIKit

// MARK: - Delegate

protocol EditorToolbarViewDelegate: AnyObject {
    func toolbarViewDidTapPlayPause(_ toolbar: EditorToolbarView)
    func toolbarViewDidTapUndo(_ toolbar: EditorToolbarView)
    func toolbarViewDidTapRedo(_ toolbar: EditorToolbarView)
}

// MARK: - EditorToolbarView

final class EditorToolbarView: UIView {

    // MARK: - Public

    weak var delegate: EditorToolbarViewDelegate?
    private(set) var isPlaying = false

    // MARK: - Top Separator

    private lazy var separatorView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGray5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Left: Play / Pause

    private lazy var playPauseButton: UIButton = {
        let symConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "play.fill", withConfiguration: symConfig)
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8)
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        btn.accessibilityLabel = "Play"
        return btn
    }()

    // MARK: - Center: Time Labels

    private lazy var currentTimeLabel: UILabel = {
        let lbl = UILabel()
        // Monospaced digits prevent the label from jumping width as the time ticks.
        lbl.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        lbl.textColor = .label
        lbl.textAlignment = .center
        lbl.text = "00:00"
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.accessibilityLabel = "Current time"
        return lbl
    }()

    private lazy var totalDurationLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.text = "00:00"
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.accessibilityLabel = "Total duration"
        return lbl
    }()

    private lazy var timeStack: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [currentTimeLabel, totalDurationLabel])
        sv.axis = .vertical
        sv.alignment = .center
        sv.spacing = 2
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Right: Undo / Redo

    private lazy var undoButton: UIButton = {
        makeControlButton(
            systemName: "arrow.uturn.backward",
            pointSize: 15,
            accessibilityLabel: "Undo",
            insets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 6),
            action: #selector(undoTapped)
        )
    }()

    private lazy var redoButton: UIButton = {
        makeControlButton(
            systemName: "arrow.uturn.forward",
            pointSize: 15,
            accessibilityLabel: "Redo",
            insets: NSDirectionalEdgeInsets(top: 8, leading: 6, bottom: 8, trailing: 16),
            action: #selector(redoTapped)
        )
    }()

    private lazy var rightStack: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [undoButton, redoButton])
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Private Setup

    private func setupView() {
        backgroundColor = .systemBackground
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(separatorView)
        addSubview(playPauseButton)
        addSubview(timeStack)
        addSubview(rightStack)

        NSLayoutConstraint.activate([
            // Hair-line separator at the very top.
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),

            // Play/Pause — flush to the leading edge.
            playPauseButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Time stack — horizontally centered in the toolbar.
            timeStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            timeStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Prevent the play button from overlapping the time stack on very narrow screens.
            timeStack.leadingAnchor.constraint(greaterThanOrEqualTo: playPauseButton.trailingAnchor, constant: 8),

            // Undo/Redo — flush to the trailing edge.
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Prevent overlap between time stack and undo/redo cluster.
            timeStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),
        ])
    }

    // MARK: - Public API

    /// Toggles the play/pause icon. Call this whenever the playback state changes.
    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        let imageName = playing ? "pause.fill" : "play.fill"
        let symConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        var config = playPauseButton.configuration
        config?.image = UIImage(systemName: imageName, withConfiguration: symConfig)
        playPauseButton.configuration = config
        playPauseButton.accessibilityLabel = playing ? "Pause" : "Play"
    }

    /// Updates the top (current playhead position) time label.
    /// - Parameter formattedTime: Pre-formatted string, e.g. `"01:23"`.
    func setCurrentTime(_ formattedTime: String) {
        currentTimeLabel.text = formattedTime
    }

    /// Updates the bottom (total project duration) time label.
    /// - Parameter formattedDuration: Pre-formatted string, e.g. `"02:47"`.
    func setTotalDuration(_ formattedDuration: String) {
        totalDurationLabel.text = formattedDuration
    }

    /// Reflects undo availability in the button's enabled state.
    func setUndoEnabled(_ enabled: Bool) {
        undoButton.isEnabled = enabled
    }

    /// Reflects redo availability in the button's enabled state.
    func setRedoEnabled(_ enabled: Bool) {
        redoButton.isEnabled = enabled
    }

    // MARK: - Actions

    @objc private func playPauseTapped() {
        delegate?.toolbarViewDidTapPlayPause(self)
    }

    @objc private func undoTapped() {
        delegate?.toolbarViewDidTapUndo(self)
    }

    @objc private func redoTapped() {
        delegate?.toolbarViewDidTapRedo(self)
    }

    // MARK: - Factory Helper

    private func makeControlButton(
        systemName: String,
        pointSize: CGFloat,
        accessibilityLabel: String,
        insets: NSDirectionalEdgeInsets,
        action: Selector
    ) -> UIButton {
        let symConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: systemName, withConfiguration: symConfig)
        config.baseForegroundColor = .label
        config.contentInsets = insets
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.accessibilityLabel = accessibilityLabel
        return btn
    }
}
