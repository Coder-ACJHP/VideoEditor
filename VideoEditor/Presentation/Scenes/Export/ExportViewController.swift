//
// ExportViewController
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import UIKit

@MainActor
final class ExportViewController: UIViewController {

    private let router: RouterDelegate
    private let project: EditingProject
    private let movieExporter: ProjectMovieExporting

    private let nameLabel = UILabel()
    private let hintLabel = UILabel()
    private let formatControl = UISegmentedControl(items: ["MOV", "MP4"])
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let percentLabel = UILabel()
    private let exportButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(router: RouterDelegate, project: EditingProject, movieExporter: ProjectMovieExporting) {
        self.router = router
        self.project = project
        self.movieExporter = movieExporter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationItem.title = String(localized: "Export")

        nameLabel.font = .preferredFont(forTextStyle: .title2)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 0
        nameLabel.text = project.name

        hintLabel.font = .preferredFont(forTextStyle: .subheadline)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.text = String(localized: "File name uses the project title. Choose a format, then save to your photo library.")

        formatControl.selectedSegmentIndex = project.exportSettings.fileType == .mov ? 0 : 1

        progressView.progress = 0
        progressView.isHidden = true

        percentLabel.font = .preferredFont(forTextStyle: .subheadline)
        percentLabel.textAlignment = .center
        percentLabel.textColor = .secondaryLabel
        percentLabel.text = "0%"
        percentLabel.isHidden = true

        exportButton.setTitle(String(localized: "Save to Photos"), for: .normal)
        exportButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)

        activityIndicator.hidesWhenStopped = true

        let stack = UIStackView(
            arrangedSubviews: [
                nameLabel,
                hintLabel,
                formatControl,
                progressView,
                percentLabel,
                exportButton,
                activityIndicator,
            ]
        )
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(24, after: hintLabel)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func selectedFileType() -> ExportSettings.ExportFileType {
        formatControl.selectedSegmentIndex == 0 ? .mov : .mp4
    }

    @objc private func exportTapped() {
        Task { await runExport() }
    }

    private func runExport() async {
        exportButton.isEnabled = false
        formatControl.isEnabled = false
        activityIndicator.startAnimating()
        progressView.isHidden = false
        percentLabel.isHidden = false
        progressView.progress = 0
        percentLabel.text = "0%"

        defer {
            activityIndicator.stopAnimating()
            exportButton.isEnabled = true
            formatControl.isEnabled = true
            progressView.isHidden = true
            percentLabel.isHidden = true
        }

        let configuration = MovieExportConfiguration(fileType: selectedFileType())

        do {
            let delivery = try await movieExporter.exportMovieToPhotoLibrary(
                project: project,
                configuration: configuration,
                progress: { [weak self] value in
                    guard let self else { return }
                    self.progressView.progress = Float(value)
                    let percent = Int((value * 100).rounded(.down))
                    self.percentLabel.text = "\(percent)%"
                }
            )

            router.pushExportedVideoResult(fileURL: delivery.fileURL, animated: true)
        } catch let movieError as MovieExportError {
            router.presentAlert(
                title: String(localized: "Export failed"),
                message: movieError.localizedDescription
            )
        } catch {
            router.presentAlert(
                title: String(localized: "Export failed"),
                message: error.localizedDescription
            )
        }
    }
}
