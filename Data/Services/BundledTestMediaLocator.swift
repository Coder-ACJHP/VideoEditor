//
//  BundledTestMediaLocator.swift
//  VideoEditor
//

import Foundation

struct BundledTestMediaLocator: BundledTestMediaLocating {

    nonisolated init() {}

    nonisolated func url(resource: String, extension ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: "Test Media") {
            return url
        }
        return Bundle.main.url(forResource: resource, withExtension: ext)
    }
}
