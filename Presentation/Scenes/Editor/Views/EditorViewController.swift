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
    private var workingTracks: [MediaTrack]

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
    private var featuresHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(router: RouterDelegate, project: EditingProject) {
        self.router  = router
        self.project = project
        self.workingTracks = project.tracks
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
            // Flexible: fills all space between the toolbar and the features bar.
            timelineView.bottomAnchor.constraint(equalTo: featuresView.topAnchor),
        ])
    }

    /// Seeds toolbar and timeline with the project’s initial state.
    private func applyInitialState() {
        toolbarView.setCurrentTime(formatTime(0))
        toolbarView.setTotalDuration(formatTime(currentProjectSnapshot.totalDuration.seconds))
        toolbarView.setUndoEnabled(false)
        toolbarView.setRedoEnabled(false)
        timelineView.configure(with: currentProjectSnapshot)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let total = max(Int(seconds), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var currentProjectSnapshot: EditingProject {
        EditingProject(
            id: project.id,
            name: project.name,
            creationDate: project.creationDate,
            lastModifiedDate: Date(),
            tracks: workingTracks,
            exportSettings: project.exportSettings
        )
    }

    private func refreshTimeline() {
        let snapshot = currentProjectSnapshot
        toolbarView.setTotalDuration(formatTime(snapshot.totalDuration.seconds))
        timelineView.configure(with: snapshot)
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
        print("Feature view didSelect item: \(item)")
    }

    func featuresViewDidTapBack(_ view: EditorFeaturesView) {
        featuresView.showMainMenu(animated: true)
    }
}
