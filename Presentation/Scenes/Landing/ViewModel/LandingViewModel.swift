//
//  LandingViewModel.swift
//  VideoEditor
//

import Foundation
import Combine
import PhotosUI

@MainActor
final class LandingViewModel {

    @Published var title: String = "Projects"
    @Published var projects: [EditingProject] = []
    @Published var isLoading: Bool = false
    @Published private(set) var selectedSortOption: SortOption = .creationDate
    let errorSubject = PassthroughSubject<String, Never>()

    private let router: RouterDelegate
    private let importService: MediaImportService
    private var allProjects: [EditingProject] = []
    
    init(router: RouterDelegate, importService: MediaImportService) {
        self.router = router
        self.importService = importService
        applySortAndPublish()
    }

    func didSelectProject(at index: Int) {
        guard projects.indices.contains(index) else { return }
        // TODO: seçilen projeyi Editor'a enjekte et (Editor tarafı hazır olunca).
        router.navigate(to: .editor, animated: true)
    }

    func setSortOption(_ option: SortOption) {
        guard selectedSortOption != option else { return }
        selectedSortOption = option
        applySortAndPublish()
    }

    func createProject(from results: [PHPickerResult]) async throws {
        guard !results.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }
        
        do {
            let imported = try await importService.importPickedItems(results)
            let project = ProjectFactory.makeNewProject(importedMedia: imported)
            
            // TODO: persistence'e kaydet.
            allProjects.insert(project, at: 0)
            applySortAndPublish()
            // router.navigate(to: .editor, animated: true)
        } catch {
            errorSubject.send(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Sorting

    enum SortOption: Equatable, CaseIterable {
        case creationDate
        case size
        case alphabetically

        var title: String {
            switch self {
            case .creationDate: return "Creation Date"
            case .size: return "Size"
            case .alphabetically: return "Alphabetically"
            }
        }
    }

    private func applySortAndPublish() {
        projects = allProjects.sorted(by: selectedSortOption.sortComparator)
    }
}

private extension LandingViewModel.SortOption {

    var sortComparator: (EditingProject, EditingProject) -> Bool {
        switch self {
        case .creationDate:
            return { $0.creationDate > $1.creationDate }
        case .size:
            return { $0.totalDuration.seconds > $1.totalDuration.seconds }
        case .alphabetically:
            return {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
}
