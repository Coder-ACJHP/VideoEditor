//
//  LocalMediaImportService.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 25.03.2026.
//

import Foundation
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

final class LocalMediaImportService: MediaImportService {
    
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    func importPickedItems(_ results: [PHPickerResult]) async throws -> [ProjectFactory.ImportedMedia] {
        var imported: [ProjectFactory.ImportedMedia] = []
        imported.reserveCapacity(results.count)
        
        for result in results {
            let provider = result.itemProvider
            
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                let url = try await copyToAppStorage(from: provider, type: .movie)
                
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                let seconds = duration.seconds
                
                imported.append(
                    ProjectFactory.ImportedMedia(
                        asset: .video(url),
                        durationSeconds: seconds.isFinite ? seconds : nil
                    )
                )
                continue
            }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let url = try await copyToAppStorage(from: provider, type: .image)
                imported.append(ProjectFactory.ImportedMedia(asset: .image(url)))
                continue
            }
        }
        
        return imported
    }
    
    func copyToAppStorage(from provider: NSItemProvider, type: UTType) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { [weak self] url, error in
                guard let self else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "LandingImport",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Internal Error, no self"]
                        )
                    )
                    return
                }
                
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let url else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "LandingImport",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing file URL"]
                        )
                    )
                    return
                }
                
                do {
                    let folder = try fileManager.url(
                        for: .cachesDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    ).appendingPathComponent("ImportedMedia", isDirectory: true)
                    
                    if !fileManager.fileExists(atPath: folder.path) {
                        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                    }
                    
                    let ext = url.pathExtension
                    let filename = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
                    let destination = folder.appendingPathComponent(filename)
                    
                    if fileManager.fileExists(atPath: destination.path) {
                        try fileManager.removeItem(at: destination)
                    }
                    
                    try fileManager.copyItem(at: url, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
