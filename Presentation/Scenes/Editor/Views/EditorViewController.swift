//
//  EditorViewController.swift
//  VideoEditor
//
//  Root view controller for the editing canvas.
//  Owns all editor sub-components and mediates between them.
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
import CoreMedia

@MainActor
final class EditorViewController: UIViewController {

    // MARK: - Dependencies

    private let router:  RouterDelegate
    private let project: EditingProject

    // MARK: - UI Components

    private let navigationBar = EditorNavigationBar()
    private let renderView    = EditorRenderView()
    private let toolbarView   = EditorToolbarView()
    private let timelineView  = EditorTimelineView()
    private let featuresView  = EditorFeaturesView()

    // MARK: - Layout

    private let collapsedHeightRatio: CGFloat = 0.40
    private let expandedHeightRatio:  CGFloat = 0.65
    private var renderViewHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(router: RouterDelegate, project: EditingProject) {
        self.router  = router
        self.project = project
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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
        navigationBar.configure(projectName: project.name, aspectRatio: "9:16")
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
            toolbarView.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func setupFeaturesView() {
        featuresView.delegate = self
        view.addSubview(featuresView)
        NSLayoutConstraint.activate([
            featuresView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            featuresView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            featuresView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            featuresView.heightAnchor.constraint(equalToConstant: EditorFeaturesView.preferredHeight),
        ])
    }

    private func setupTimelineView() {
        timelineView.delegate = self
        view.addSubview(timelineView)
        NSLayoutConstraint.activate([
            timelineView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            timelineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timelineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Flexible: fills all space between the toolbar and the features bar.
            timelineView.bottomAnchor.constraint(equalTo: featuresView.topAnchor),
        ])
    }

    /// Seeds toolbar and timeline with the project’s initial state.
    private func applyInitialState() {
        toolbarView.setCurrentTime(formatTime(0))
        toolbarView.setTotalDuration(formatTime(project.totalDuration.seconds))
        toolbarView.setUndoEnabled(false)
        toolbarView.setRedoEnabled(false)
        timelineView.configure(with: project)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
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

        renderView.setExpanded(isExpanding)

        UIView.animate(
            withDuration: 0.42,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.15,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
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
        toolbarView.setCurrentTime(formatTime(seconds))
        // TODO: Seek the playback engine to `seconds`.
    }

    func timelineView(_ timeline: EditorTimelineView, didSelectTrackKind kind: TimelineTrackView.Kind) {
        let trackType: MediaTrack.TrackType = kind == .video ? .video : .audio
        featuresView.showSubMenu(items: FeatureItem.subMenuItems(for: trackType), animated: true)
    }
}

// MARK: - EditorFeaturesViewDelegate

extension EditorViewController: EditorFeaturesViewDelegate {

    func featuresView(_ view: EditorFeaturesView, didSelectItem item: FeatureItem) {
        // Allow manual sub-menu preview from the main menu as well,
        // so UI can be tested without selecting a timeline clip first.
        guard !featuresView.isShowingSubMenu else {
            // TODO: Route sub-menu actions by `item.id`.
            return
        }

        switch item.id {
        case "audio", "voice":
            featuresView.showSubMenu(items: FeatureItem.subMenuItems(for: .audio), animated: true)
        case "sticker":
            featuresView.showSubMenu(items: FeatureItem.subMenuItems(for: .overlay), animated: true)
        default:
            // Video/image-centric tools: filters, adjust, effects, etc.
            featuresView.showSubMenu(items: FeatureItem.subMenuItems(for: .video), animated: true)
        }
    }

    func featuresViewDidTapBack(_ view: EditorFeaturesView) {
        featuresView.showMainMenu(animated: true)
    }
}
