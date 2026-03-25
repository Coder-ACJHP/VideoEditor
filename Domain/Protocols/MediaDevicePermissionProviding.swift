//
//  MediaDevicePermissionProviding.swift
//  VideoEditor
//

import Foundation

/// Domain-level errors for photo library and camera permission flows.
enum MediaPermissionError: Error, LocalizedError, Equatable {
    case photoLibraryDenied
    case photoLibraryRestricted
    case photoLibraryAddDenied
    case photoLibraryAddRestricted
    case cameraDenied
    case cameraRestricted
    case cameraUnavailable

    var errorDescription: String? {
        switch self {
        case .photoLibraryDenied:
            return "Photo library access is required to import media. You can enable it in Settings."
        case .photoLibraryRestricted:
            return "Photo library access is restricted on this device."
        case .photoLibraryAddDenied:
            return "Permission to save to your photo library was denied. You can enable it in Settings."
        case .photoLibraryAddRestricted:
            return "Saving to the photo library is restricted on this device."
        case .cameraDenied:
            return "Camera access is required to record video. You can enable it in Settings."
        case .cameraRestricted:
            return "Camera access is restricted on this device."
        case .cameraUnavailable:
            return "No camera is available on this device."
        }
    }
}

/// Abstraction for system media permissions (Photos + camera).
/// Implemented in the Data layer so the domain stays free of AVFoundation/Photos imports.
protocol MediaDevicePermissionProviding: Sendable {

    /// Read/write photo library access (`NSPhotoLibraryUsageDescription`). Use before gallery / PHPicker when you rely on full library APIs.
    func ensurePhotoLibraryReadAccess() async throws

    /// Add-only access (`NSPhotoLibraryAddUsageDescription`). Use before saving exports to the library.
    func ensurePhotoLibraryAddAccess() async throws

    /// Video capture permission (`NSCameraUsageDescription`). Use before presenting `UIImagePickerController` or `AVCaptureSession`.
    func ensureCameraAccess() async throws
}
