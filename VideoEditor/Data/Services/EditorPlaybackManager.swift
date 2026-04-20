//
// EditorPlaybackManager
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import AVFoundation
import UIKit

final class EditorPlaybackManager {

    private enum PostAttachBehavior {
        case pausedAtTimelineStart
        case playFromPreviewHead
    }

    /// Playhead sync on the main thread after playback, seek, or a new composition attach.
    var onPlaybackTimeSecondsUpdated: ((Double) -> Void)?
    /// Fired when the item reaches the end (toolbar play state).
    var onPlaybackDidReachEnd: (() -> Void)?

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private let compositionBuilder: CompositionBuilding

    private var periodicTimeObserver: Any?
    private var playbackEndObserver: NSObjectProtocol?
    /// Scrub target while paused so the periodic time observer does not overwrite it.
    private var previewTimelineSeconds: Double = 0
    /// Last successful `build` attach; same `compositionGeneration` skips rebuild on Play.
    private var lastAttachedCompositionGeneration: UInt64?

    init(compositionBuilder: CompositionBuilding = PreviewTimelineCompositionBuilder()) {
        self.compositionBuilder = compositionBuilder
    }

    func play(project: EditingProject, compositionGeneration: UInt64, in renderView: EditorRenderView) async {
        if lastAttachedCompositionGeneration == compositionGeneration,
           let p = player,
           p.currentItem != nil {
            await seekToClampedPreviewHead(player: p)
            p.play()
            publishPlaybackTime()
            return
        }
        await rebuildAndAttach(
            project: project,
            compositionGeneration: compositionGeneration,
            in: renderView,
            postAttach: .playFromPreviewHead
        )
    }

    func loadPreview(project: EditingProject, compositionGeneration: UInt64, in renderView: EditorRenderView) async {
        if lastAttachedCompositionGeneration == compositionGeneration,
           player?.currentItem != nil {
            return
        }
        await rebuildAndAttach(
            project: project,
            compositionGeneration: compositionGeneration,
            in: renderView,
            postAttach: .pausedAtTimelineStart
        )
    }

    func pause() {
        player?.pause()
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        previewTimelineSeconds = seconds
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.publishPlaybackTime()
        }
    }

    // MARK: - Private

    private func rebuildAndAttach(
        project: EditingProject,
        compositionGeneration: UInt64,
        in renderView: EditorRenderView,
        postAttach: PostAttachBehavior
    ) async {
        do {
            let result = try await compositionBuilder.build(from: project)
            removePlaybackEndObserver()

            if player == nil {
                let newPlayer = AVPlayer(playerItem: result.playerItem)
                newPlayer.automaticallyWaitsToMinimizeStalling = false
                let layer = renderView.hostedPlayerLayer
                layer.player = newPlayer
                layer.videoGravity = .resizeAspect
                player = newPlayer
                playerLayer = layer
                installPeriodicTimeObserverIfNeeded(on: newPlayer)
            } else {
                player?.replaceCurrentItem(with: result.playerItem)
                player?.automaticallyWaitsToMinimizeStalling = false
            }
            lastAttachedCompositionGeneration = compositionGeneration

            switch postAttach {
            case .pausedAtTimelineStart:
                player?.pause()
                await player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                previewTimelineSeconds = player?.currentTime().seconds ?? 0
            case .playFromPreviewHead:
                if let player = player {
                    await seekToClampedPreviewHead(player: player)
                    player.play()
                }
            }

            publishPlaybackTime()
            registerPlaybackEndObserver(for: result.playerItem)

        } catch {
            #if DEBUG
            print("Composition build error:", error)
            #endif
        }
    }

    private func seekToClampedPreviewHead(player: AVPlayer) async {
        guard let item = player.currentItem else { return }
        let seekSeconds = Self.clampedTimelineSeconds(
            desired: previewTimelineSeconds,
            itemDuration: item.duration
        )
        previewTimelineSeconds = seekSeconds
        await player.seek(
            to: CMTime(seconds: seekSeconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func installPeriodicTimeObserverIfNeeded(on player: AVPlayer) {
        guard periodicTimeObserver == nil else { return }

        let interval = CMTime(seconds: 1.0 / 60.0, preferredTimescale: 600)
        periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self, let player = self.player else { return }

            let advancing = player.timeControlStatus == .playing || player.rate > 0
            if advancing {
                let time = player.currentTime()
                if time.isValid && !time.isIndefinite {
                    let seconds = time.seconds
                    if seconds.isFinite {
                        self.previewTimelineSeconds = max(0, seconds)
                        self.publishPlaybackTime()
                    }
                }
            }
        }
    }

    private func publishPlaybackTime() {
        onPlaybackTimeSecondsUpdated?(previewTimelineSeconds)
    }

    private static func clampedTimelineSeconds(desired: Double, itemDuration: CMTime) -> Double {
        let lo = max(0, desired)
        guard itemDuration.isValid, !itemDuration.isIndefinite else { return lo }
        let hi = max(0, itemDuration.seconds)
        return min(lo, hi)
    }

    private func removePlaybackEndObserver() {
        if let obs = playbackEndObserver {
            NotificationCenter.default.removeObserver(obs)
            playbackEndObserver = nil
        }
    }

    private func registerPlaybackEndObserver(for item: AVPlayerItem) {
        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.pause()
            self.onPlaybackDidReachEnd?()
        }
    }
}
