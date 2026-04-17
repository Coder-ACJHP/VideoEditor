//
// ExportedVideoResultViewController
// VideoEditor
//

import AVKit
import UIKit

@MainActor
final class ExportedVideoResultViewController: UIViewController {

    private let fileURL: URL
    private let onBack: () -> Void

    private let playerViewController = AVPlayerViewController()

    init(fileURL: URL, onBack: @escaping () -> Void) {
        self.fileURL = fileURL
        self.onBack = onBack
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        try? FileManager.default.removeItem(at: fileURL)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        navigationItem.title = String(localized: "Export complete")

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: String(localized: "Back"),
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )

        let player = AVPlayer(url: fileURL)
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true

        addChild(playerViewController)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerViewController.view)
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        playerViewController.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Edge swipe would only pop this screen (not Export) and would deallocate us while the flow expects both to dismiss together.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }

    @objc private func backTapped() {
        playerViewController.player?.pause()
        onBack()
    }

    @objc private func shareTapped() {
        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activity, animated: true)
    }
}
