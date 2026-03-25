//
//  LandingViewController.swift
//  VideoEditor
//

import UIKit
import Combine
import PhotosUI

enum LandingSection: String, Hashable, Sendable {
    case main
}

final class LandingViewController: UIViewController {

    // MARK: - UI

    private lazy var createProjectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Create project"
        config.image = UIImage(systemName: "plus")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .preferredFont(forTextStyle: .title1)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(createNewProjectTapped), for: .touchUpInside)
        return button
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            ))
            item.contentInsets = .init(top: 6, leading: 6, bottom: 6, trailing: 6)

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(
                    widthDimension: .fractionalWidth(1.0 / 3),
                    heightDimension: .estimated(240)
                ),
                repeatingSubitem: item,
                count: 3
            )

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
            return section
        }

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.delegate = self
        cv.register(ProjectCell.self, forCellWithReuseIdentifier: ProjectCell.reuseIdentifier)
        return cv
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No projects yet.\nTap ‘Create project’ to start."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
 
    private let loadingOverlay = LoadingOverlayView(blocksTouches: true)

    // MARK: - State

    private var projects: [EditingProject] = []
    private var cancellables: Set<AnyCancellable> = []
    
    private let viewModel: LandingViewModel
    typealias DataSource = UICollectionViewDiffableDataSource<LandingSection, EditingProject>
    typealias Snapshot = NSDiffableDataSourceSnapshot<LandingSection, EditingProject>
    private var dataSource: DataSource!
    
    /// Shared thumbnail service injected into every cell.
    /// One instance = one cache shared across all visible cells,
    /// so the same asset is never decoded twice per session.
    private let thumbnailService: ThumbnailGenerating
    private let mediaPermissions: MediaDevicePermissionProviding

    // MARK: - Init

    init(
        router: RouterDelegate,
        thumbnailService: ThumbnailGenerating = LocalThumbnailService(),
        mediaPermissions: MediaDevicePermissionProviding = SystemMediaPermissionService()
    ) {
        self.thumbnailService = thumbnailService
        self.mediaPermissions = mediaPermissions
        self.viewModel = LandingViewModel(
            router: router,
            importService: LocalMediaImportService()
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground

        navigationItem.title = viewModel.title
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        navigationItem.rightBarButtonItem = makeSortBarButtonItem()

        setupUI()
        bindViewModel()
        viewModel.loadStoredProjects()
    }

    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(emptyStateLabel)
        view.addSubview(createProjectButton)
        view.addSubview(loadingOverlay)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: createProjectButton.topAnchor, constant: -12),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            
            createProjectButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            createProjectButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            createProjectButton.heightAnchor.constraint(equalToConstant: 56.resp),
            createProjectButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateEmptyState()
        
        // Drop shadow to continue button
        createProjectButton.dropOuterShadow(
            withColor: createProjectButton.configuration?.baseBackgroundColor?.withAlphaComponent(0.2) ?? .systemBlue,
            radius: 5,
            opacity: 1.0,
            offset: CGSize(width: 0, height: 5)
        )
        
        configureDataSource()
    }

    private func bindViewModel() {
        
        // Loading state
        viewModel.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.setLoading(state)
            }
            .store(in: &cancellables)
        
        // Projects
        viewModel.$projects
            .receive(on: RunLoop.main)
            .sink { [weak self] projects in
                guard let self else { return }
                self.projects = projects
                var snapshot = Snapshot()
                snapshot.appendSections([.main])
                snapshot.appendItems(projects, toSection: .main)
                self.dataSource.apply(snapshot, animatingDifferences: true)
                self.updateEmptyState()
            }
            .store(in: &cancellables)
        
        // Error handling
        viewModel.errorSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                self?.presentImportError(message)
            }
            .store(in: &cancellables)
    }
    
    private func setLoading(_ isLoading: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = !isLoading
        collectionView.isUserInteractionEnabled = !isLoading
        createProjectButton.isEnabled = !isLoading
        navigationItem.rightBarButtonItem?.isEnabled = !isLoading
        loadingOverlay.setLoading(isLoading, animated: true)
    }

    private func updateEmptyState() {
        let isEmpty = projects.isEmpty
        collectionView.isHidden = isEmpty
        emptyStateLabel.isHidden = !isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !isEmpty && !(viewModel.isLoading)
    }
    
    func configureDataSource() {
        let registration = UICollectionView.CellRegistration<ProjectCell, EditingProject> { [weak self] cell, indexPath, item in
            guard let self else { return }
            cell.configure(
                with: item,
                thumbnailService: self.thumbnailService,
                projectActionsMenu: self.makeProjectActionsMenu(for: item)
            )
        }

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, project in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: project)
        }

        // Initial empty snapshot
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        dataSource.apply(snapshot, animatingDifferences: false)
    }



    // MARK: - Actions

    private func makeSortBarButtonItem() -> UIBarButtonItem {
        let creation = UIAction(
            title: LandingViewModel.SortOption.creationDate.title,
            state: viewModel.selectedSortOption == .creationDate ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.setSortOption(.creationDate)
            self?.navigationItem.rightBarButtonItem = self?.makeSortBarButtonItem()
        }

        let size = UIAction(
            title: LandingViewModel.SortOption.size.title,
            state: viewModel.selectedSortOption == .size ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.setSortOption(.size)
            self?.navigationItem.rightBarButtonItem = self?.makeSortBarButtonItem()
        }

        let alphabetically = UIAction(
            title: LandingViewModel.SortOption.alphabetically.title,
            state: viewModel.selectedSortOption == .alphabetically ? .on : .off
        ) { [weak self] _ in
            self?.viewModel.setSortOption(.alphabetically)
            self?.navigationItem.rightBarButtonItem = self?.makeSortBarButtonItem()
        }

        let menu = UIMenu(children: [creation, size, alphabetically])
        return UIBarButtonItem(title: nil, image: UIImage(systemName: "arrow.up.arrow.down"), primaryAction: nil, menu: menu)
    }

    @objc
    private func createNewProjectTapped() {
        let sheet = UIAlertController(title: "Create New Project", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Gallery", style: .default) { [weak self] _ in
            self?.presentGalleryAfterPermissionCheck()
        })

        sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
            self?.presentCameraAfterPermissionCheck()
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = createProjectButton
            popover.sourceRect = createProjectButton.bounds
        }

        present(sheet, animated: true)
    }

    private func presentCameraAfterPermissionCheck() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.mediaPermissions.ensureCameraAccess()
                self.presentCameraNotReadyAlert()
            } catch let error as MediaPermissionError {
                self.presentMediaPermissionAlert(error: error)
            } catch {
                self.presentImportError(error.localizedDescription)
            }
        }
    }

    private func presentCameraNotReadyAlert() {
        let alert = UIAlertController(
            title: "Coming soon",
            message: "Camera import will be added later.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentGalleryAfterPermissionCheck() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.mediaPermissions.ensurePhotoLibraryReadAccess()
                self.presentGalleryPicker()
            } catch let error as MediaPermissionError {
                self.presentMediaPermissionAlert(error: error)
            } catch {
                self.presentImportError(error.localizedDescription)
            }
        }
    }

    private func presentGalleryPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .any(of: [.images, .videos])

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentMediaPermissionAlert(error: MediaPermissionError) {
        let alert = UIAlertController(
            title: "Permission needed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if error != .cameraUnavailable, error != .photoLibraryRestricted,
           error != .photoLibraryAddRestricted, error != .cameraRestricted {
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            })
        }
        present(alert, animated: true)
    }

    private func presentImportError(_ errorMessage: String) {
        let alert = UIAlertController(
            title: "Import failed",
            message: errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentRenameProjectAlert(project: EditingProject) {
        let alert = UIAlertController(
            title: "Rename project",
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.text = project.name
            field.autocapitalizationType = .words
            field.clearButtonMode = .whileEditing
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text else { return }
            self.viewModel.renameProject(id: project.id, to: text)
            // Diffable data treats same `id` as unchanged; reload after the published snapshot applies.
            DispatchQueue.main.async { [weak self] in
                guard let self, let updated = self.viewModel.projects.first(where: { $0.id == project.id }) else { return }
                var snapshot = self.dataSource.snapshot()
                snapshot.reloadItems([updated])
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
        })

        present(alert, animated: true)
    }

    private func presentDeleteProjectConfirmation(project: EditingProject) {
        let alert = UIAlertController(
            title: "Delete project?",
            message: "“\(project.name)” will be removed. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.viewModel.deleteProject(id: project.id)
        })
        present(alert, animated: true)
    }

    private func makeProjectActionsMenu(for project: EditingProject) -> UIMenu {
        let rename = UIAction(
            title: "Rename project",
            image: UIImage(systemName: "pencil")
        ) { [weak self] _ in
            self?.presentRenameProjectAlert(project: project)
        }
        let delete = UIAction(
            title: "Delete project",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.presentDeleteProjectConfirmation(project: project)
        }
        return UIMenu(title: "", children: [rename, delete])
    }
}

// MARK: - UICollectionView

extension LandingViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        projects.count
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.didSelectProject(at: indexPath.item)
    }
}

// MARK: - PHPicker

extension LandingViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            try await self.viewModel.createProject(from: results)
        }
    }
}

