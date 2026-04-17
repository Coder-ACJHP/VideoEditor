//
// EditorViewController
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

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

import CoreMedia
import UIKit

@MainActor
final class EditorViewController: UIViewController {

    // MARK: - Dependencies

    let router: RouterDelegate
    let viewModel: EditorViewModel
    let thumbnailGenerator: ThumbnailGenerating
    let playbackManager = EditorPlaybackManager()
    let mediaPermissions: MediaDevicePermissionProviding = SystemMediaPermissionService()
    let mediaImportService: MediaImportService = LocalMediaImportService()

    // MARK: - UI Components

    let navigationBar = EditorNavigationBar()
    let renderView = EditorRenderView()
    let toolbarView = EditorToolbarView()
    let featuresView = EditorFeaturesView()
    lazy var timelineView = EditorTimelineView(
        thumbnailGenerator: thumbnailGenerator
    )

    // MARK: - Layout

    let collapsedHeightRatio: CGFloat = 0.40
    let expandedHeightRatio: CGFloat = 0.65
    var renderViewHeightConstraint: NSLayoutConstraint?
    var featuresHeightConstraint: NSLayoutConstraint?
    private var didLoadInitialPreview = false
    /// Preserves playhead time when reloading preview after `didUpdateTracks`.
    var latestPlaybackTimelineSeconds: Double = 0
    /// Clip currently highlighted in the timeline while the features sub menu is relevant (e.g. delete).
    var selectedTimelineClipId: UUID?

    /// Draft text row while “add text” sheet is open (not yet in `EditorViewModel`).
    /// Internal so `EditorViewController+RenderView` can apply canvas gestures before the clip exists in the model.
    var textSheetDraft: (id: UUID, descriptor: TextOverlayDescriptor, transform: TransformEffect)?
    /// Existing clip ids being edited via the text sheet (add flow uses draft only).
    var textSheetFocusedExistingClipIds: Set<UUID> = []

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
        wirePlaybackTimelineSync()
        applyInitialState()
    }

    /// Keeps the timeline and time label aligned with playback; skips updates while the user scrolls the timeline horizontally.
    private func wirePlaybackTimelineSync() {
        playbackManager.onPlaybackTimeSecondsUpdated = { [weak self] seconds in
            guard let self else { return }
            guard !self.timelineView.isUserAdjustingHorizontalScroll else { return }
            self.latestPlaybackTimelineSeconds = max(0, seconds)
            self.viewModel.notePlaybackTimelineSeconds(self.latestPlaybackTimelineSeconds)
            self.timelineView.setCurrentTime(seconds)
            self.toolbarView.setCurrentTime(self.viewModel.formattedScrubTime(seconds: seconds))
            self.refreshCanvasOverlays()
        }
        playbackManager.onPlaybackDidReachEnd = { [weak self] in
            self?.toolbarView.setPlaying(false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didLoadInitialPreview else { return }
        didLoadInitialPreview = true
        renderView.layoutIfNeeded()
        Task { [weak self] in
            guard let self else { return }
            await self.playbackManager.loadPreview(
                project: self.viewModel.projectSnapshot(),
                compositionGeneration: self.viewModel.previewCompositionGeneration,
                in: self.renderView
            )
            self.refreshCanvasOverlays()
        }
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
        renderView.overlayDelegate = self
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
    func presentAudioBottomSheet() {
        let configuration = EditorFeatureSheetPresentationMapper.audioPickerSheetConfiguration()
        let sheet = AudioBottomSheetViewController(router: router) { [weak self] item in
            guard let self else { return }
            Task {
                await self.viewModel.addAudioFromBrowseItem(item)
            }
        }
        router.presentBottomSheet(sheet, config: configuration, animated: true)
    }

    func presentCanvasBackgroundBottomSheet() {
        let configuration = EditorFeatureSheetPresentationMapper.canvasBackgroundSheetConfiguration()
        let sheet = CanvasBackgroundBottomSheetViewController(
            initial: viewModel.canvasBackground
        ) { [weak self] settings in
            guard let self else { return }
            self.viewModel.setCanvasBackground(settings)
            self.reloadPreviewComposition()
        }
        router.presentBottomSheet(sheet, config: configuration, animated: true)
    }

    func reloadPreviewComposition() {
        let resumeSeconds = latestPlaybackTimelineSeconds
        Task { [weak self] in
            guard let self else { return }
            await self.playbackManager.loadPreview(
                project: self.viewModel.projectSnapshot(),
                compositionGeneration: self.viewModel.previewCompositionGeneration,
                in: self.renderView
            )
            self.playbackManager.seek(to: resumeSeconds)
            self.refreshCanvasOverlays()
        }
    }

    /// Presents the transition grid for the seam after `clipIndex` on the master video track.
    func presentTransitionPickerBottomSheet(afterMasterClipAt clipIndex: Int, currentTransition: ClipTransition?) {
        let configuration = EditorFeatureSheetPresentationMapper.transitionPickerSheetConfiguration()
        let sheet = TransitionPickerBottomSheetViewController(currentTransition: currentTransition) { [weak self] transition in
            self?.timelineView.applyMasterTrackTransitionOut(transition, afterClipAt: clipIndex)
        }
        router.presentBottomSheet(sheet, config: configuration, animated: true)
    }

    func presentTextBottomSheet() {
        let draftClipId = UUID()
        let initial = TextOverlayDescriptor.defaultNew(text: "")
        textSheetDraft = (id: draftClipId, descriptor: initial, transform: .identity)
        textSheetFocusedExistingClipIds = []
        renderView.setActiveOverlayClipId(draftClipId)
        refreshCanvasOverlays()
        let sheet = TextBottomSheetViewController(
            initialDescriptor: initial,
            onDescriptorChange: { [weak self] descriptor in
                guard let self else { return }
                if var d = self.textSheetDraft {
                    d.descriptor = descriptor
                    self.textSheetDraft = d
                }
                self.renderView.updateTextOverlayContent(clipId: draftClipId, descriptor: descriptor)
            },
            onCancel: { [weak self] in
                self?.clearTextSheetSessionState()
                self?.syncCanvasOverlaysFromProject()
            },
            onComplete: { [weak self] descriptor in
                guard let self else { return }
                let transform = self.textSheetDraft?.transform ?? .identity
                self.clearTextSheetSessionState()
                Task {
                    await self.viewModel.addTextOverlay(with: descriptor, transform: transform)
                }
            }
        )
        present(sheet, animated: true)
    }

    /// Text sheet for the timeline-selected text clip; Done writes back into the model.
    func presentTextEditSheet(for clipId: UUID) {
        guard let initial = viewModel.textOverlayDescriptor(for: clipId) else { return }
        textSheetDraft = nil
        textSheetFocusedExistingClipIds = [clipId]
        renderView.setActiveOverlayClipId(clipId)
        refreshCanvasOverlays()
        let sheet = TextBottomSheetViewController(
            initialDescriptor: initial,
            onDescriptorChange: { [weak self] descriptor in
                self?.renderView.updateTextOverlayContent(clipId: clipId, descriptor: descriptor)
            },
            onCancel: { [weak self] in
                self?.clearTextSheetSessionState()
                self?.syncCanvasOverlaysFromProject()
            },
            onComplete: { [weak self] descriptor in
                self?.clearTextSheetSessionState()
                self?.viewModel.replaceTextOverlayDescriptor(clipId: clipId, descriptor: descriptor)
                self?.syncCanvasOverlaysFromProject()
            }
        )
        present(sheet, animated: true)
    }

    func syncCanvasOverlaysFromProject() {
        refreshCanvasOverlays()
    }

    /// Binds UIKit text + sticker overlays at the playhead (omitted from preview `AVComposition`, like text).
    func refreshCanvasOverlays() {
        let playhead = CMTime(seconds: latestPlaybackTimelineSeconds, preferredTimescale: 600)
        let draft = textSheetDraft.map {
            EditorCanvasTextDraft(clipId: $0.id, descriptor: $0.descriptor, transform: $0.transform)
        }
        let input = EditorCanvasOverlayRefreshInput(
            clips: viewModel.overlayCanvasClipsInPaintOrder(),
            playhead: playhead,
            timelineSelectedClipId: selectedTimelineClipId,
            canvasActiveClipId: renderView.activeOverlayClipId,
            sheetFocusedClipIds: textSheetFocusedExistingClipIds,
            textDraft: draft
        )
        let result = BuildEditorCanvasOverlayState.make(input: input)
        renderView.applyOverlays(
            text: result.textRows,
            stickers: result.stickerRows,
            paintOrder: result.paintOrderClipIds
        )
    }

    func clearTextSheetSessionState() {
        textSheetDraft = nil
        textSheetFocusedExistingClipIds = []
    }
}
