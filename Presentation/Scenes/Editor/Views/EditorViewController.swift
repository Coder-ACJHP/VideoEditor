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
    private let thumbnailGenerator: ThumbnailGenerating
    private var workingTracks: [MediaTrack]

    // MARK: - UI Components

    private let navigationBar = EditorNavigationBar()
    private let renderView    = EditorRenderView()
    private let toolbarView   = EditorToolbarView()
    private let featuresView  = EditorFeaturesView()
    private lazy var timelineView  = EditorTimelineView(
        thumbnailGenerator: thumbnailGenerator
    )

    // MARK: - Layout

    private let collapsedHeightRatio: CGFloat = 0.40
    private let expandedHeightRatio:  CGFloat = 0.65
    private var renderViewHeightConstraint: NSLayoutConstraint?
    private var featuresHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(
        router: RouterDelegate,
        project: EditingProject,
        thumbnailGenerator: ThumbnailGenerating
    ) {
        self.router  = router
        self.project = project
        self.thumbnailGenerator = thumbnailGenerator
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

    /// Duration of the master (video) timeline in seconds.
    /// Non-video clips are clamped to this when a master exists.
    private var masterTrackDuration: Double? {
        let videoTracks = workingTracks.filter { $0.trackType == .video }
        guard !videoTracks.isEmpty else { return nil }
        let end = videoTracks
            .flatMap(\.clips)
            .map(\.timelineRange.endSeconds)
            .max() ?? 0
        return end > 0 ? end : nil
    }

    // MARK: - Temporary Test Inserts

    /// Looks up a bundled test-media file in `Resources/Test Media`.
    private func bundledTestMediaURL(resource: String, withExtension ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: "Test Media") {
            return url
        }
        return Bundle.main.url(forResource: resource, withExtension: ext)
    }

    /// Temporary text-to-image utility for timeline testing.
    /// Later this will receive real user input from the text tool UI.
    private func makeTextImageURL(for text: String) -> URL? {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 720, height: 220), format: rendererFormat)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]

            let textRect = CGRect(x: 24, y: 40, width: 672, height: 140)
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }

        guard let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-text-\(UUID().uuidString)")
            .appendingPathExtension("png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("Failed to write text image: \(error)")
            return nil
        }
    }

    /// Temporary helper for quickly appending a clip.
    /// By default each inserted test media gets its own dedicated track lane.
    private func appendTemporaryClip(
        to trackType: MediaTrack.TrackType,
        asset: AssetIdentifier,
        duration: Double,
        alwaysCreateNewTrack: Bool = true
    ) async {
        let minDuration = TimelineConfiguration.default.minClipDuration
        let safeDuration = max(duration, minDuration)
        let timelineDuration: Double
        if trackType == .video {
            timelineDuration = safeDuration
        } else if let masterDuration = masterTrackDuration {
            timelineDuration = min(safeDuration, masterDuration)
        } else {
            timelineDuration = safeDuration
        }
        let sourceDuration = await AssetDurationResolver.sourceDuration(for: asset) ?? safeDuration
        let sourceRange = ClipTimeRange(startSeconds: 0, durationSeconds: sourceDuration)

        if alwaysCreateNewTrack {
            let range = ClipTimeRange(startSeconds: 0, durationSeconds: timelineDuration)
            let clip = MediaClip(asset: asset, timelineRange: range, sourceRange: sourceRange)
            workingTracks.append(MediaTrack(trackType: trackType, clips: [clip]))
            refreshTimeline()
            return
        }

        if let existingIndex = workingTracks.firstIndex(where: { $0.trackType == trackType }) {
            let start = workingTracks[existingIndex].clips.map(\.timelineRange.endSeconds).max() ?? 0
            let range = ClipTimeRange(startSeconds: start, durationSeconds: timelineDuration)
            let clip = MediaClip(asset: asset, timelineRange: range, sourceRange: sourceRange)
            workingTracks[existingIndex].clips.append(clip)
        } else {
            let range = ClipTimeRange(startSeconds: 0, durationSeconds: timelineDuration)
            let clip = MediaClip(asset: asset, timelineRange: range, sourceRange: sourceRange)
            let track = MediaTrack(trackType: trackType, clips: [clip])
            workingTracks.append(track)
        }

        refreshTimeline()
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

    func timelineView(_ timeline: EditorTimelineView, didSelectClipWithMediaType mediaType: AssetIdentifier.MediaType) {
        featuresView.showSubMenu(items: FeatureItem.subMenuItems(for: mediaType), animated: true)
    }

    func timelineViewDidDeselectAll(_ timeline: EditorTimelineView) {
        featuresView.showMainMenu(animated: true)
    }

    func timelineView(_ timeline: EditorTimelineView, didExtendDurationTo seconds: Double) {
        toolbarView.setTotalDuration(formatTime(seconds))
    }

    func timelineView(_ timeline: EditorTimelineView, didUpdateTracks tracks: [MediaTrack]) {
        workingTracks = tracks
    }
}

// MARK: - EditorFeaturesViewDelegate

extension EditorViewController: EditorFeaturesViewDelegate {

    func featuresView(_ view: EditorFeaturesView, didSelectItem item: FeatureItem) {
        // NOTE: Temporary test-only shortcuts requested by product/dev:
        // Audio/Text/Sticker taps append synthetic clips directly to timeline.
        Task { @MainActor in
            switch item.id {
                case "audio":
                    guard let url = bundledTestMediaURL(resource: "Reflection", withExtension: "mp3") else {
                        print("Missing bundled test media: Reflection.mp3")
                        return
                    }
                    let asset: AssetIdentifier = .audio(url)
                    let duration = await AssetDurationResolver.sourceDuration(for: asset) ?? 5
                    await appendTemporaryClip(to: .audio, asset: asset, duration: duration)
                case "text":
                    guard let url = makeTextImageURL(for: "Sample Text") else {
                        print("Failed to generate temporary text image")
                        return
                    }
                    await appendTemporaryClip(to: .overlay, asset: .image(url), duration: 3)
                case "sticker":
                    guard let url = bundledTestMediaURL(resource: "img1", withExtension: "jpg") else {
                        print("Missing bundled test media: img1.jpg")
                        return
                    }
                    await appendTemporaryClip(to: .overlay, asset: .image(url), duration: 3)
                default:
                    print("Feature view didSelect item: \(item)")
            }
        }
    }

    func featuresViewDidTapBack(_ view: EditorFeaturesView) {
        featuresView.showMainMenu(animated: true)
    }
}
