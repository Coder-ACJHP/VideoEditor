//
// TimelineTrackView
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  A single horizontal track lane inside the timeline scroll view.
//  Renders each MediaClip as a positioned, colored block.
//  Frame-based layout is intentional: clip positions derive from
//  time values, not from parent bounds, so Auto Layout adds nothing here.
//
//  Timeline behavior rules used in this file:
//  1) Master track is the `.video` lane and is the single source of truth
//     for project duration.
//  2) Master-track clips must stay contiguous (no gaps). After edits, clips
//     are packed edge-to-edge, first clip starts at t=0.
//  3) Master track can both extend and shrink the timeline based on its
//     rightmost clip end.
//  4) Non-master tracks do not control shrink. They resolve overlaps locally
//     and only request timeline extension when needed.
//  5) Master-track contiguity is computed in Domain (`TimelineArranging`); this view
//     applies the resulting `timelineRange` values to frames.
//

import UIKit
import UniformTypeIdentifiers

// MARK: - Delegate

protocol TimelineTrackViewDelegate: AnyObject {
    /// Fired when the user taps a clip block in this track lane.
    func trackView(_ view: TimelineTrackView, didTapClipAt index: Int, clipId: UUID, mediaType: AssetIdentifier.MediaType)
    /// Fired when the user deselects a clip (taps the same clip again).
    func trackViewDidDeselectClip(_ view: TimelineTrackView)
    /// Fired when a clip extends beyond the current track width, requesting the timeline to grow.
    func trackView(_ view: TimelineTrackView, didRequestTimelineExtensionTo newDuration: Double)
    /// Fired when the master (video) track's total duration shrinks after a trim.
    func trackView(_ view: TimelineTrackView, didRequestTimelineShrinkTo newDuration: Double)
    /// Fired whenever this lane's clip model changes due to drag/trim/collision updates.
    func trackView(_ view: TimelineTrackView, didUpdateTrack track: MediaTrack)
    /// Master-track clip reorder: mirrors visibility of the yellow insertion guide; host shows a warning label.
    func trackView(_ view: TimelineTrackView, masterReorderTransitionWarningVisible: Bool)
    /// Master-track seam: user chose to edit the transition after `clipIndex`.
    func trackView(
        _ view: TimelineTrackView,
        didRequestTransitionPickerAfterClipAt clipIndex: Int,
        currentTransition: ClipTransition?
    )
}

// MARK: - TimelineTrackView

final class TimelineTrackView: UIView {
    // MARK: - Public

    let trackType: MediaTrack.TrackType
    weak var delegate: TimelineTrackViewDelegate?

    /// Read-only snapshot of the current track model (after any live edits).
    var currentTrackSnapshot: MediaTrack? { currentTrack }

    // MARK: - Private

    private var clipViews: [TrackMediaView] = []
    private let config = TimelineConfiguration.default
    private var layout: TimelineLayoutProvider = TimelineConfiguration.default.timelineLayout
    private var currentTrack: MediaTrack?
    private var maxTrackDuration: Double = 0
    private var durationLimitOverride: Double?
    private let thumbnailGenerator: ThumbnailGenerating
    private let timelineArranger: TimelineArranging
    private weak var selectedMediaView: TrackMediaView?

    /// Transition affordances between master-track clips; owned by the lane so hit testing sits on the seam, not inside a clip.
    private var seamTransitionControls: [(leftClipIndex: Int, button: SeamTransitionButton)] = []

    /// Vertical “drop cursor” while reordering master clips via drag and drop.
    private var reorderInsertionGuideLine: UIView?
    /// Keeps guide X aligned when `layoutSubviews` runs during an active drop session.
    private var reorderGuideLineInsertionIndex: Int?

    // MARK: - Init

    init(
        trackType: MediaTrack.TrackType,
        thumbnailGenerator: ThumbnailGenerating,
        timelineArranger: TimelineArranging = MasterTrackTimelineArranger()
    ) {
        self.trackType = trackType
        self.thumbnailGenerator = thumbnailGenerator
        self.timelineArranger = timelineArranger
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = config.trackLaneBackgroundColor
        layer.cornerRadius = config.trackLaneCornerRadius
        clipsToBounds = true
        if trackType == .video {
            let guide = UIView()
            guide.backgroundColor = config.reorderInsertionGuideLineColor
            guide.isUserInteractionEnabled = false
            guide.isHidden = true
            guide.layer.zPosition = 2500
            guide.layer.cornerRadius = config.reorderInsertionGuideLineWidth / 2
            guide.layer.masksToBounds = true
            addSubview(guide)
            reorderInsertionGuideLine = guide
            addInteraction(UIDropInteraction(delegate: self))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Selection

    func deselectAll() {
        selectedMediaView?.setSelected(false)
        selectedMediaView = nil
        updateSeamTransitionControlAppearance()
    }

    /// Programmatic selection (e.g. text chosen on canvas). Returns `false` if no clip on this lane matches.
    @discardableResult
    func selectClip(withClipId clipId: UUID) -> Bool {
        guard let track = currentTrack else { return false }
        guard let index = track.clips.firstIndex(where: { $0.id == clipId }) else { return false }
        guard clipViews.indices.contains(index) else { return false }
        let mediaView = clipViews[index]
        if selectedMediaView !== mediaView {
            selectedMediaView?.setSelected(false)
            selectedMediaView = mediaView
        }
        mediaView.setSelected(true)
        updateSeamTransitionControlAppearance()
        return true
    }

    // MARK: - Duration Limit

    /// Pushes a new duration ceiling from the master track and clamps
    /// any clips whose right edge now exceeds that ceiling.
    func updateDurationLimit(_ limit: Double?) {
        durationLimitOverride = limit
        let ceiling = effectiveTrackDurationLimit
        let maxPx = layout.xPosition(forSeconds: ceiling)

        for view in clipViews {
            view.updateTrackLimits(maxDuration: ceiling)
            guard view.frame.maxX > maxPx else { continue }

            let clampedWidth = max(maxPx - view.frame.origin.x, 0)
            let minW = layout.width(forDurationSeconds: config.minClipDuration)
            guard clampedWidth >= minW else { continue }

            view.frame.size.width = clampedWidth

            let duration = layout.seconds(forXPosition: clampedWidth)
            let range = ClipTimeRange(
                startSeconds: layout.seconds(forXPosition: view.frame.origin.x),
                durationSeconds: duration
            )
            view.applyTimelineRange(range)

            var src = view.sourceRange
            src.durationSeconds = duration
            view.applySourceRange(src)

            guard var track = currentTrack else { continue }
            guard track.clips.indices.contains(view.tag) else { continue }
            track.clips[view.tag].timelineRange = range
            track.clips[view.tag].sourceRange.durationSeconds = duration
            currentTrack = track
        }
    }

    // MARK: - Configuration

    func configure(
        with track: MediaTrack?,
        layout: TimelineLayoutProvider,
        durationLimitOverride: Double? = nil
    ) {
        self.layout = layout
        self.currentTrack = track
        self.durationLimitOverride = durationLimitOverride
        self.maxTrackDuration = layout.durationSeconds(forContentWidth: bounds.width)

        clipViews.forEach { $0.removeFromSuperview() }
        clipViews.removeAll()
        removeAllSeamTransitionControls()
        selectedMediaView = nil

        guard let track else { return }

        for (index, clip) in track.clips.enumerated() {
            let v = makeClipView(for: clip, at: index)
            addSubview(v)
            clipViews.append(v)
        }
        buildSeamTransitionControls()
        if trackType == .video, let guide = reorderInsertionGuideLine {
            bringSubviewToFront(guide)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        maxTrackDuration = layout.durationSeconds(forContentWidth: bounds.width)
        clipViews.forEach {
            $0.updateTrackLimits(maxDuration: effectiveTrackDurationLimit)
            $0.frame.size.height = trackContentHeight
        }

        // Earlier master clips draw above later ones so the transition
        // chip (centered on the seam) stays visible over the next clip.
        if trackType == .video {
            let count = clipViews.count
            for (index, mediaView) in clipViews.enumerated() {
                mediaView.layer.zPosition = CGFloat(count - index - 1)
            }
        } else {
            clipViews.forEach { $0.layer.zPosition = 0 }
        }

        layoutSeamTransitionControlFrames()
        updateSeamTransitionControlAppearance()
        if reorderInsertionGuideLine?.isHidden == false {
            applyReorderInsertionGuideLineFrame()
        }
    }

    // MARK: - Private Helpers

    private var trackContentHeight: CGFloat { bounds.height }
    private var effectiveTrackDurationLimit: Double { durationLimitOverride ?? maxTrackDuration }

    private func makeClipView(for clip: MediaClip, at index: Int) -> TrackMediaView {
        let xPos  = layout.xPosition(forSeconds: clip.timelineRange.startSeconds)
        let width = layout.width(forDurationSeconds: clip.timelineRange.durationSeconds)
        let safeW  = max(width, 48)
        let frame = CGRect(
            x:      xPos,
            y:      0,
            width:  safeW,
            height: trackContentHeight
        )

        let mediaView = makeMediaView(for: clip, frame: frame)
        mediaView.tag = index
        mediaView.delegate = self
        mediaView.isMasterTrack = (trackType == .video)
        mediaView.updateTrackLimits(maxDuration: effectiveTrackDurationLimit)
        mediaView.setSelected(false)
        mediaView.applyTimelineRange(clip.timelineRange)
        return mediaView
    }

    private func makeMediaView(for clip: MediaClip, frame: CGRect) -> TrackMediaView {
        switch clip.asset.mediaType {
        case .video:
            return VideoTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout,
                thumbnailGenerator: thumbnailGenerator
            )
        case .audio:
            return AudioTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout
            )
        case .image:
            return ImageTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout,
                thumbnailGenerator: thumbnailGenerator
            )
        case .text:
            return TextTrackMediaView(
                frame: frame,
                clip: clip,
                layout: layout
            )
        }
    }

    // MARK: - Master track transition seams

    /// Wider than the 24pt glyph so the seam control matches HIG-style targets.
    private final class SeamTransitionButton: UIButton {
        private let minimumHitExtent: CGFloat = 44

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return false }
            let dx = max(0, (minimumHitExtent - bounds.width) / 2)
            let dy = max(0, (minimumHitExtent - bounds.height) / 2)
            return bounds.insetBy(dx: -dx, dy: -dy).contains(point)
        }
    }

    private func removeAllSeamTransitionControls() {
        seamTransitionControls.forEach { $0.button.removeFromSuperview() }
        seamTransitionControls.removeAll()
    }

    private func buildSeamTransitionControls() {
        removeAllSeamTransitionControls()
        guard trackType == .video, let track = currentTrack, track.clips.count > 1 else { return }

        for leftIndex in 0..<(track.clips.count - 1) {
            let leftClip = track.clips[leftIndex]
            guard isVisualPrimaryMasterClip(leftClip) else { continue }

            let capturedIndex = leftIndex
            let button = SeamTransitionButton(
                configuration: transitionButtonConfiguration(isActive: leftClip.transitionOut != nil),
                primaryAction: UIAction { [weak self] _ in
                    self?.presentTransitionPicker(afterClipAt: capturedIndex)
                }
            )
            button.clipsToBounds = true
            button.accessibilityLabel = "Transition to next clip"
            button.layer.zPosition = 500 + CGFloat(leftIndex)
            addSubview(button)
            seamTransitionControls.append((leftClipIndex: leftIndex, button: button))
        }
    }

    private func layoutSeamTransitionControlFrames() {
        guard trackType == .video else { return }
        let s = TimelineConfiguration.default.masterTransitionAffordanceSize
        for item in seamTransitionControls {
            let i = item.leftClipIndex
            guard clipViews.indices.contains(i), i < clipViews.count - 1 else { continue }
            let seamX = clipViews[i].frame.maxX
            item.button.frame = CGRect(
                x: seamX - s / 2,
                y: (trackContentHeight - s) / 2,
                width: s,
                height: s
            )
        }
    }

    private func updateSeamTransitionControlAppearance() {
        guard trackType == .video, let track = currentTrack else { return }
        for item in seamTransitionControls {
            let i = item.leftClipIndex
            guard track.clips.indices.contains(i), clipViews.indices.contains(i), i < clipViews.count - 1 else {
                item.button.isHidden = true
                item.button.isUserInteractionEnabled = false
                continue
            }
            let unselected = selectedMediaView !== clipViews[i]
            let show = unselected && isVisualPrimaryMasterClip(track.clips[i])
            item.button.isHidden = !show
            item.button.isUserInteractionEnabled = show
            applyTransitionButtonStyle(to: item.button, transition: track.clips[i].transitionOut)
        }
    }

    private func isVisualPrimaryMasterClip(_ clip: MediaClip) -> Bool {
        switch clip.asset.mediaType {
        case .video, .image, .text:
            return true
        case .audio:
            return false
        }
    }

    private func transitionButtonConfiguration(isActive: Bool) -> UIButton.Configuration {
        let size = config.masterTransitionAffordanceSize
        var bgConfig = UIBackgroundConfiguration.clear()
        bgConfig.backgroundColor = isActive
            ? UIColor.black.withAlphaComponent(0.62)
            : UIColor.black.withAlphaComponent(0.45)
        bgConfig.cornerRadius = size / 2

        var btnConfig = UIButton.Configuration.plain()
        btnConfig.background = bgConfig
        btnConfig.cornerStyle = .dynamic
        btnConfig.contentInsets = .zero
        btnConfig.imagePlacement = .all
        btnConfig.imagePadding = 6
        btnConfig.baseForegroundColor = isActive ? config.selectionColor : .white
        let sym = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        btnConfig.image = UIImage(systemName: "arrow.left.arrow.right.circle", withConfiguration: sym)?
            .withRenderingMode(.alwaysTemplate)
        return btnConfig
    }

    private func applyTransitionButtonStyle(to button: SeamTransitionButton, transition: ClipTransition?) {
        button.configuration = transitionButtonConfiguration(isActive: transition != nil)
    }

    private func presentTransitionPicker(afterClipAt clipIndex: Int) {
        guard trackType == .video else { return }
        guard let track = currentTrack else { return }
        guard track.clips.indices.contains(clipIndex), clipIndex < track.clips.count - 1 else { return }
        let current = track.clips[clipIndex].transitionOut
        delegate?.trackView(
            self,
            didRequestTransitionPickerAfterClipAt: clipIndex,
            currentTransition: current
        )
    }

    /// Commits a transition on the master video track; use from the editor sheet host.
    func commitMasterTransitionOut(_ transition: ClipTransition?, afterClipAt index: Int) {
        guard trackType == .video else { return }
        applyTransitionOut(transition, forClipAt: index)
    }
}

// MARK: - TrackMediaViewDelegate

extension TimelineTrackView: TrackMediaViewDelegate {
    func trackMediaViewDidToggleSelection(_ view: TrackMediaView) {
        if selectedMediaView === view {
            view.setSelected(false)
            selectedMediaView = nil
            delegate?.trackViewDidDeselectClip(self)
            updateSeamTransitionControlAppearance()
            return
        }

        selectedMediaView?.setSelected(false)
        selectedMediaView = view
        view.setSelected(true)

        let clips = currentTrack?.clips ?? []
        guard clips.indices.contains(view.tag) else { return }
        let clip = clips[view.tag]
        delegate?.trackView(self, didTapClipAt: view.tag, clipId: clip.id, mediaType: clip.asset.mediaType)
        updateSeamTransitionControlAppearance()
    }

    func trackMediaView(_ view: TrackMediaView, didChangeTimelineRange range: ClipTimeRange, sourceRange: ClipTimeRange, allowExtension: Bool) {
        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(view.tag) else { return }
        track.clips[view.tag].timelineRange = range
        track.clips[view.tag].sourceRange = sourceRange
        currentTrack = track

        if trackType == .video {
            if allowExtension {
                applyMasterTrackContiguityFromDomain()
                requestTimelineResizeIfNeeded()
            }
        } else {
            resolveCollisions(from: view)
            if allowExtension {
                requestTimelineExtensionIfNeeded()
            }
        }
        // Commit (notifyTrackUpdated) runs only after the gesture ends — see `trackMediaViewDidCommitInteractiveTimelineChange`.
    }

    func trackMediaViewDidCommitInteractiveTimelineChange(_ view: TrackMediaView) {
        notifyTrackUpdated()
    }

    // MARK: - Master Track Contiguity (Domain)

    /// Runs `TimelineArranging` on the current model, then syncs clip views from `timelineRange`.
    private func applyMasterTrackContiguityFromDomain() {
        guard var track = currentTrack else { return }
        track.clips = timelineArranger.enforceMasterTrackContiguity(clips: track.clips)
        currentTrack = track
        applyMasterTrackClipViewsFromModel()
    }

    private func applyMasterTrackClipViewsFromModel() {
        guard let track = currentTrack else { return }
        for index in track.clips.indices {
            guard index < clipViews.count else { continue }

            let view = clipViews[index]
            let clip = track.clips[index]
            let x = layout.xPosition(forSeconds: clip.timelineRange.startSeconds)
            let w = layout.width(forDurationSeconds: clip.timelineRange.durationSeconds)
            let safeW = max(w, 48)

            view.frame.origin.x = x
            view.frame.size.width = safeW
            view.applyTimelineRange(clip.timelineRange)
        }
        updateSeamTransitionControlAppearance()
    }

    /// For the master track: extends OR shrinks the timeline to match the arranged model end.
    private func requestTimelineResizeIfNeeded() {
        guard let track = currentTrack, trackType == .video, !track.clips.isEmpty else { return }

        let maxEndSeconds = track.clips.map(\.timelineRange.endSeconds).max() ?? 0
        let maxEndPx = layout.xPosition(forSeconds: maxEndSeconds)
        let currentWidthPx = bounds.width
        let newDuration = maxEndSeconds

        if maxEndPx > currentWidthPx {
            delegate?.trackView(self, didRequestTimelineExtensionTo: newDuration)
        } else if maxEndPx < currentWidthPx {
            delegate?.trackView(self, didRequestTimelineShrinkTo: newDuration)
        }
    }

    // MARK: - Sub-Track Collision Resolution

    /// For non-master tracks: pushes neighbours apart to prevent overlap.
    private func resolveCollisions(from movedView: TrackMediaView) {
        let mediaViews = clipViews
        guard mediaViews.count > 1 else { return }

        let sorted = mediaViews.sorted { $0.frame.minX < $1.frame.minX }
        guard let movedIndex = sorted.firstIndex(where: { $0 === movedView }) else { return }

        for i in movedIndex ..< (sorted.count - 1) {
            let current = sorted[i]
            let next    = sorted[i + 1]
            if current.frame.maxX > next.frame.minX {
                next.frame.origin.x = current.frame.maxX
                updateClipRange(for: next)
            }
        }

        for i in stride(from: movedIndex, through: 1, by: -1) {
            let current = sorted[i]
            let prev    = sorted[i - 1]
            if prev.frame.maxX > current.frame.minX {
                let newX = max(current.frame.minX - prev.frame.width, 0)
                prev.frame.origin.x = newX
                updateClipRange(for: prev)
            }
        }

        for i in 0 ..< (sorted.count - 1) {
            let current = sorted[i]
            let next    = sorted[i + 1]
            if current.frame.maxX > next.frame.minX {
                next.frame.origin.x = current.frame.maxX
                updateClipRange(for: next)
            }
        }
    }

    /// Syncs a pushed clip's frame back into its model range.
    private func updateClipRange(for view: TrackMediaView) {
        let newStart = layout.seconds(forXPosition: view.frame.origin.x)
        let duration = layout.seconds(forXPosition: view.frame.width)
        let range = ClipTimeRange(startSeconds: newStart, durationSeconds: duration)
        view.applyTimelineRange(range)

        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(view.tag) else { return }
        track.clips[view.tag].timelineRange = range
        currentTrack = track
    }

    /// If the rightmost clip exceeds the track's visible width, ask the parent to extend.
    private func requestTimelineExtensionIfNeeded() {
        let mediaViews = clipViews
        guard let maxEndPx = mediaViews.map({ $0.frame.maxX }).max() else { return }

        let currentWidthPx = bounds.width
        guard maxEndPx > currentWidthPx else { return }

        let newDuration = layout.seconds(forXPosition: maxEndPx)
        delegate?.trackView(self, didRequestTimelineExtensionTo: newDuration)
    }

    private func notifyTrackUpdated() {
        guard let track = currentTrack else { return }
        delegate?.trackView(self, didUpdateTrack: track)
    }

    // MARK: - Master track reorder (UIDropInteraction)

    /// Maps a horizontal position in this lane to an insertion index (0…clipCount) using clip midpoints.
    private func masterTrackInsertionIndex(forTimelineX x: CGFloat) -> Int {
        var index = 0
        for mediaView in clipViews {
            if x > mediaView.frame.midX { index += 1 }
        }
        return min(index, clipViews.count)
    }

    /// Horizontal center for the insertion guide at a given insertion index (boundary before clip at `index`).
    private func masterTrackInsertionLineCenterX(forInsertionIndex insertion: Int) -> CGFloat {
        guard !clipViews.isEmpty else { return 0 }
        let bounded = min(max(0, insertion), clipViews.count)
        if bounded == 0 {
            return clipViews[0].frame.minX
        }
        if bounded >= clipViews.count {
            return clipViews[clipViews.count - 1].frame.maxX
        }
        return clipViews[bounded - 1].frame.maxX
    }

    private func hideReorderInsertionGuideLine() {
        reorderInsertionGuideLine?.isHidden = true
        reorderGuideLineInsertionIndex = nil
        delegate?.trackView(self, masterReorderTransitionWarningVisible: false)
    }

    private func refreshReorderInsertionGuideLine(with session: UIDropSession) {
        guard let guide = reorderInsertionGuideLine else { return }
        guard !clipViews.isEmpty else {
            hideReorderInsertionGuideLine()
            return
        }
        let insertion = masterTrackInsertionIndex(forTimelineX: session.location(in: self).x)
        reorderGuideLineInsertionIndex = insertion
        guide.isHidden = false
        delegate?.trackView(self, masterReorderTransitionWarningVisible: true)
        setNeedsLayout()
        layoutIfNeeded()
        applyReorderInsertionGuideLineFrame()
    }

    private func applyReorderInsertionGuideLineFrame() {
        guard let guide = reorderInsertionGuideLine,
              let insertion = reorderGuideLineInsertionIndex else { return }
        let centerX = masterTrackInsertionLineCenterX(forInsertionIndex: insertion)
        let thickness = config.reorderInsertionGuideLineWidth
        guide.frame = CGRect(
            x: centerX - thickness / 2,
            y: 0,
            width: thickness,
            height: trackContentHeight
        )
    }

    /// Reorders master `clips` and `clipViews`, repacks timeline times, rebuilds seams, and notifies the delegate.
    private func reorderMasterTrackClips(from fromIndex: Int, toInsertionIndex insertionBeforeRemoval: Int) {
        guard trackType == .video else { return }
        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(fromIndex) else { return }
        guard clipViews.indices.contains(fromIndex) else { return }
        guard clipViews.count == track.clips.count else { return }

        var insertAt = insertionBeforeRemoval
        if fromIndex < insertAt { insertAt -= 1 }
        guard insertAt >= 0, insertAt <= track.clips.count - 1 else { return }
        if insertAt == fromIndex { return }

        var clips = track.clips
        let movedClip = clips.remove(at: fromIndex)
        clips.insert(movedClip, at: insertAt)
        for i in clips.indices {
            clips[i].transitionOut = nil
        }

        var reorderedViews = clipViews
        let movedView = reorderedViews.remove(at: fromIndex)
        reorderedViews.insert(movedView, at: insertAt)

        track.clips = timelineArranger.enforceMasterTrackContiguity(clips: clips)
        currentTrack = track
        clipViews = reorderedViews

        for (i, v) in clipViews.enumerated() {
            v.tag = i
        }
        applyMasterTrackClipViewsFromModel()
        removeAllSeamTransitionControls()
        buildSeamTransitionControls()
        layoutSeamTransitionControlFrames()
        updateSeamTransitionControlAppearance()
        requestTimelineResizeIfNeeded()
        notifyTrackUpdated()
    }

    private func applyTransitionOut(_ transition: ClipTransition?, forClipAt index: Int) {
        guard var track = currentTrack else { return }
        guard track.clips.indices.contains(index) else { return }
        track.clips[index].transitionOut = transition
        currentTrack = track
        applyMasterTrackContiguityFromDomain()
        requestTimelineResizeIfNeeded()
        notifyTrackUpdated()
    }

}

// MARK: - Master track reorder (UIDropInteractionDelegate)

extension TimelineTrackView: UIDropInteractionDelegate {

    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        guard trackType == .video else { return false }
        guard session.localDragSession != nil else { return false }
        return session.hasItemsConforming(toTypeIdentifiers: [UTType.plainText.identifier])
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        guard trackType == .video else { return }
        refreshReorderInsertionGuideLine(with: session)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        guard trackType == .video, session.localDragSession != nil else {
            hideReorderInsertionGuideLine()
            return UIDropProposal(operation: .forbidden)
        }
        refreshReorderInsertionGuideLine(with: session)
        return UIDropProposal(operation: .move)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        hideReorderInsertionGuideLine()
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        hideReorderInsertionGuideLine()
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        guard trackType == .video else { return }
        hideReorderInsertionGuideLine()
        guard let clipId = session.items.first?.localObject as? UUID else { return }
        guard let fromIndex = currentTrack?.clips.firstIndex(where: { $0.id == clipId }) else { return }
        let location = session.location(in: self)
        let insertion = masterTrackInsertionIndex(forTimelineX: location.x)
        reorderMasterTrackClips(from: fromIndex, toInsertionIndex: insertion)
    }
}
