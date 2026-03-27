//
//  BundledTestMediaLocating.swift
//  VideoEditor
//
//  Resolves URLs for sample assets shipped under Resources (e.g. Test Media).
//

import Foundation

protocol BundledTestMediaLocating: Sendable {
    func url(resource: String, extension ext: String) -> URL?
}
