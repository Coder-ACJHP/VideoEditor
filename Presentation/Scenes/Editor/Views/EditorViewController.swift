//
//  EditorViewController.swift
//  VideoEditor
//
//  Root view controller for the editing canvas.
//  Owns layout and subview wiring; session state lives in EditorViewModel.
//
//  Full layout (top → bottom):
//  ┌─────────────────────────────────────────────┐
//  │ EditorNavigationBar   52 pt (fixed)             │
//  ├─────────────────────────────────────────────┤
//  │ EditorRenderView      40–65 % of view height     │
//  ├─────────────────────────────────────────────┤
//  │ EditorToolbarView     52 pt (fixed)             │
//  ├─────────────────────────────────────────────┤
//  │ EditorTimelineView    fills remaining space ↑↓   │
//  ├─────────────────────────────────────────────┤
//  │ EditorFeaturesView    70 pt (fixed)             │
//  └─────────────────────────────────────────────┘
//

import UIKit

@MainActor
final class EditorViewController: UIViewController {

    // MARK: - Dependencies

    private let router: RouterDelegate
    private let viewModel: EditorViewModel
    private let thumbnailGenerator: ThumbnailGenerating

    // MARK: - UI Components

    private let navigationBar = EditorNavigationBar()
    private let renderView = EditorRenderView()
    private let toolbarView = EditorToolbarView()
    private let featuresView = EditorFeaturesView()
    private lazy var timelineView = EditorTimelineView(
        thumbnailGenerator: thumbnailGenerator
    )

    // MARK: - Layout

    private let collapsedHeightRatio: CGFloat = 0.40
    private let expandedHeightRatio: CGFloat = 0.65
    private var renderViewHeightConstraint: NSLayoutConstraint?
    private var featuresHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(
        router: RouterDelegate,
        viewModel: EditorViewModel,
        thumbnailGenerator: ThumbnailGenerating
    ) {
        self.router = router
        self.viewModel = viewModel
        self.thumbnailGenerator = thumbnailGenerator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "editor.root"
        viewModel.delegate = self
        setupNavigationBar()
        setupRenderView()
        setupToolbarView()
        // FeaturesView must be added before TimelineView so the timeline can anchor to its top.
        setupFeaturesView()
        setupTimelineView()
        applyInitialState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationBar.delegate = self
        view.addSubview(navigationBar)
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: 52),
        ])
        navigationBar.configure(projectName: viewModel.projectDisplayName, aspectRatio: "9:16")
    }

    private func setupRenderView() {
        renderView.delegate = self
        view.addSubview(renderView)
        let heightConstraint = renderView.heightAnchor.constraint(
            equalTo: view.heightAnchor,
            multiplier: collapsedHeightRatio
        )
        renderViewHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            renderView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint,
        ])
    }

    private func setupToolbarView() {
        toolbarView.delegate = self
        view.addSubview(toolbarView)
        NSLayoutConstraint.activate([
            toolbarView.topAnchor.constraint(equalTo: renderView.bottomAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 52.resp),
        ])
    }

    private func setupFeaturesView() {
        featuresView.delegate = self
        view.addSubview(featuresView)
        let heightConstraint = featuresView.heightAnchor.constraint(equalToConstant: EditorFeaturesView.preferredHeight)
        featuresHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            featuresView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            featuresView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            featuresView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            heightConstraint,
        ])
    }

    private func setupTimelineView() {
        timelineView.delegate = self
        view.addSubview(timelineView)
        NSLayoutConstraint.activate([
            timelineView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timelineView.bottomAnchor.constraint(equalTo: featuresView.topAnchor),
        ])
    }

    /// Toolbar defaults; timeline + total duration come from the view model.
    private func applyInitialState() {
        toolbarView.setCurrentTime(TimelineClockFormatter.string(fromSeconds: 0))
        toolbarView.setUndoEnabled(false)
        toolbarView.setRedoEnabled(false)
        viewModel.start()
    }

    /// Presents the audio browser built in-editor so the confirm handler can call into `EditorViewModel`.
    private func presentAudioBottomSheet() {
        let configuration = EditorFeatureSheetPresentationMapper.audioPickerSheetConfiguration()
        let sheet = AudioBottomSheetViewController(router: router) { [weak self] item in
            guard let self else { return }
            Task {
                await self.viewModel.addAudioFromBrowseItem(item)
            }
        }
        router.presentBottomSheet(sheet, config: configuration, animated: true)
    }
}

// MARK: - EditorViewModelDelegate

extension EditorViewController: EditorViewModelDelegate {

    func editorViewModelDidRequestTimelineReload(_ viewModel: EditorViewModel) {
        timelineView.configure(with: viewModel.projectSnapshot())
    }

    func editorViewModel(_ viewModel: EditorViewModel, didUpdateToolbarTotalDuration formatted: String) {
        toolbarView.setTotalDuration(formatted)
    }
}

// MARK: - EditorNavigationBarDelegate

extension EditorViewController: EditorNavigationBarDelegate {

    func editorNavBarDidTapClose(_ navBar: EditorNavigationBar) {
        router.pop(animated: true)
    }

    func editorNavBarDidTapTitle(_ navBar: EditorNavigationBar) {
        // TODO: Present rename / project-options action sheet.
    }

    func editorNavBarDidTapNext(_ navBar: EditorNavigationBar) {
        router.navigate(to: .export, animated: true)
    }
}

// MARK: - EditorRenderViewDelegate

extension EditorViewController: EditorRenderViewDelegate {

    func renderView(_ renderView: EditorRenderView, didRequestToggleSizeWithExpanding isExpanding: Bool) {
        let newRatio = isExpanding ? expandedHeightRatio : collapsedHeightRatio

        renderViewHeightConstraint?.isActive = false
        let newConstraint = renderView.heightAnchor.constraint(
            equalTo: view.heightAnchor,
            multiplier: newRatio
        )
        newConstraint.isActive = true
        renderViewHeightConstraint = newConstraint

        featuresHeightConstraint?.constant = isExpanding ? 0 : EditorFeaturesView.preferredHeight
        featuresView.alpha = isExpanding ? 0 : 1
        featuresView.isUserInteractionEnabled = !isExpanding
        if !isExpanding {
            featuresView.showMainMenu(animated: false)
        }

        timelineView.setExpandedPreviewMode(isExpanding, animated: true)
        renderView.setExpanded(isExpanding)

        UIView.animate(
            withDuration: 1.0,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.15,
            options: [.curveEaseInOut, .allowUserInteraction, .layoutSubviews]
        ) { self.view.layoutIfNeeded() }
    }
}

// MARK: - EditorToolbarViewDelegate

extension EditorViewController: EditorToolbarViewDelegate {

    func toolbarViewDidTapPlayPause(_ toolbar: EditorToolbarView) {
        // TODO: Hook up to the playback engine.
        toolbar.setPlaying(!toolbar.isPlaying)
    }

    func toolbarViewDidTapUndo(_ toolbar: EditorToolbarView) {
        // TODO: Connect to the command stack.
    }

    func toolbarViewDidTapRedo(_ toolbar: EditorToolbarView) {
        // TODO: Connect to the command stack.
    }
}

// MARK: - EditorTimelineViewDelegate

extension EditorViewController: EditorTimelineViewDelegate {

    func timelineView(_ timeline: EditorTimelineView, didScrubToTime seconds: Double) {
        toolbarView.setCurrentTime(viewModel.formattedScrubTime(seconds: seconds))
        // TODO: Seek the playback engine to `seconds`.
    }

    func timelineView(_ timeline: EditorTimelineView, didSelectClipWithMediaType mediaType: AssetIdentifier.MediaType) {
        featuresView.showSubMenu(items: FeatureItem.subMenuItems(for: mediaType), animated: true)
    }

    func timelineViewDidDeselectAll(_ timeline: EditorTimelineView) {
        featuresView.showMainMenu(animated: true)
    }

    func timelineView(_ timeline: EditorTimelineView, didExtendDurationTo seconds: Double) {
        viewModel.onMasterTimelineDurationChanged(seconds: seconds)
    }

    func timelineView(_ timeline: EditorTimelineView, didUpdateTracks tracks: [MediaTrack]) {
        viewModel.syncTracksFromTimeline(tracks)
    }
}

// MARK: - EditorFeaturesViewDelegate

extension EditorViewController: EditorFeaturesViewDelegate {

    func featuresView(_ view: EditorFeaturesView, didSelectItem item: FeatureItem) {
        if item.id == "audio" {
            presentAudioBottomSheet()
            return
        }
        guard let presentation = EditorFeatureSheetPresentationMapper.presentation(for: item) else {
            print("Feature view didSelect item: \(item)")
            return
        }
        router.presentBottomSheet(
            to: presentation.route,
            config: presentation.configuration,
            animated: true
        )
    }

    func featuresViewDidTapBack(_ view: EditorFeaturesView) {
        featuresView.showMainMenu(animated: true)
    }
}

