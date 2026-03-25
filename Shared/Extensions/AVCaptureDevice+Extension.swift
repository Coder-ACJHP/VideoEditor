//
//  AVCaptureDevice+Extension.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 25.03.2026.
//

import Foundation
import AVFoundation

// MARK: - AVCaptureDevice + hardware probe

extension AVCaptureDevice {

    /// True when the device has at least one camera suitable for `AVCaptureDevice.DeviceType` video capture
    /// (avoids treating Simulator / audio-only hardware as “await permission” when no camera exists).
    static func hardwareMinimumPositionExists(for mediaType: AVMediaType) -> Bool {
        guard mediaType == .video else { return false }
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.first != nil
    }
}
