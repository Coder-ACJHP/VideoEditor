//
//  SystemMediaPermissionService.swift
//  VideoEditor
//

import AVFoundation
import Foundation
import Photos

/// Resolves photo library and camera authorization against system APIs.
struct SystemMediaPermissionService: MediaDevicePermissionProviding {

    func ensurePhotoLibraryReadAccess() async throws {
        try await resolvePhotoAccess(level: .readWrite, denied: .photoLibraryDenied, restricted: .photoLibraryRestricted)
    }

    func ensurePhotoLibraryAddAccess() async throws {
        try await resolvePhotoAccess(level: .addOnly, denied: .photoLibraryAddDenied, restricted: .photoLibraryAddRestricted)
    }

    func ensureCameraAccess() async throws {
        guard AVCaptureDevice.hardwareMinimumPositionExists(for: .video) else {
            throw MediaPermissionError.cameraUnavailable
        }

        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { continuation.resume(returning: $0) }
            }
            status = granted ? .authorized : .denied
        }

        switch status {
        case .authorized:
            return
        case .denied:
            throw MediaPermissionError.cameraDenied
        case .restricted:
            throw MediaPermissionError.cameraRestricted
        case .notDetermined:
            throw MediaPermissionError.cameraDenied
        @unknown default:
            throw MediaPermissionError.cameraDenied
        }
    }

    // MARK: - Private

    private func resolvePhotoAccess(
        level: PHAccessLevel,
        denied: MediaPermissionError,
        restricted: MediaPermissionError
    ) async throws {
        var status = PHPhotoLibrary.authorizationStatus(for: level)
        if status == .notDetermined {
            status = await requestPhotoLibraryAuthorization(for: level)
        }

        switch status {
        case .authorized, .limited:
            return
        case .denied:
            throw denied
        case .restricted:
            throw restricted
        case .notDetermined:
            throw denied
        @unknown default:
            throw denied
        }
    }

    private func requestPhotoLibraryAuthorization(for level: PHAccessLevel) async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: level) { continuation.resume(returning: $0) }
        }
    }
}
