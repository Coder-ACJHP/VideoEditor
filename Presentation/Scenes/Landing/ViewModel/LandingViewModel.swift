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
        router.navigateToEditor(with: projects[index], animated: true)
    }
    
    /// Updates display name and `lastModifiedDate`. Ignores empty / whitespace-only names.
    func renameProject(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = allProjects.firstIndex(where: { $0.id == id }) else { return }
        allProjects[idx].name = trimmed
        allProjects[idx].lastModifiedDate = Date()
        applySortAndPublish()
    }
    
    func loadStoredProjects() {
        // Persistence integration is pending; keep startup list empty instead of mock data.
        allProjects = [
            EditingProject(
                id: UUID(),
                name: "Mock Project X",
                creationDate: Date().addingTimeInterval(-600),
                lastModifiedDate: Date(),
                tracks: [
                    MediaTrack(
                        id: UUID(),
                        trackType: .video,
                        clips: [
                            MediaClip(
                                id: UUID(),
                                imageAsset: .image(Bundle.main.bundleURL.appendingPathComponent("img1.jpg")),
                                timelineOffset: .zero,
                                duration: 3.0,
                                transitionOut: ClipTransition(type: .slide, durationSeconds: 1.0),
                                opacity: 1.0
                            ),
                            MediaClip(
                                id: UUID(),
                                imageAsset: .image(Bundle.main.bundleURL.appendingPathComponent("img2.png")),
                                timelineOffset: 3.0,
                                duration: 3.0,
                                transitionOut: ClipTransition(type: .slide, durationSeconds: 1.0),
                                opacity: 1.0
                            ),
                            MediaClip(
                                id: UUID(),
                                imageAsset: .image(Bundle.main.bundleURL.appendingPathComponent("img3.jpeg")),
                                timelineOffset: 6.0,
                                duration: 3.0,
                                transitionOut: ClipTransition(type: .slide, durationSeconds: 1.0),
                                opacity: 1.0
                            ),
                            MediaClip(
                                id: UUID(),
                                imageAsset: .image(Bundle.main.bundleURL.appendingPathComponent("img4.jpeg")),
                                timelineOffset: 9.0,
                                duration: 3.0,
                                transitionOut: ClipTransition(type: .slide, durationSeconds: 1.0),
                                opacity: 1.0
                            ),
                            MediaClip(
                                id: UUID(),
                                imageAsset: .image(Bundle.main.bundleURL.appendingPathComponent("img5.jpeg")),
                                timelineOffset: 12.0,
                                duration: 3.0,
                                transitionOut: nil,
                                opacity: 1.0
                            )
                        ],
                        isMuted: false,
                        volume: 1.0
                    ), // Images
                    MediaTrack(
                        id: UUID(),
                        trackType: .audio,
                        clips: [
                            MediaClip(
                                id: UUID(),
                                imageAsset: .audio(Bundle.main.bundleURL.appendingPathComponent("Reflection.mp3")),
                                timelineOffset: .zero,
                                duration: 10.0,
                                transitionOut: nil,
                                opacity: 1.0
                            )
                        ],
                        isMuted: false,
                        volume: 1.0
                    ), // Audio
                    MediaTrack(
                        id: UUID(),
                        trackType: .overlay,
                        clips: [
                            MediaClip(
                                id: UUID(),
                                imageAsset: .image(Bundle.main.bundleURL.appendingPathComponent("sticker1.png")),
                                timelineOffset: .zero,
                                duration: 3.0,
                                transitionOut: nil,
                                opacity: 1.0
                            )
                        ],
                        isMuted: false,
                        volume: 1.0
                    ), // Overlay(sticker)
                    MediaTrack(
                        id: UUID(),
                        trackType: .overlay,
                        clips: [
                            MediaClip(
                                id: UUID(),
                                imageAsset: .text(TextOverlayDescriptor.defaultNew(text: "Text overlay")),
                                timelineOffset: .zero,
                                duration: 3.0,
                                transitionOut: nil,
                                opacity: 1.0
                            )
                        ],
                        isMuted: false,
                        volume: 1.0
                    )  // Overlay(text)
                ],
                exportSettings: ExportSettings.default
            )
            
        ]
        applySortAndPublish()
    }
    
    func deleteProject(id: UUID) {
        allProjects.removeAll { $0.id == id }
        applySortAndPublish()
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
