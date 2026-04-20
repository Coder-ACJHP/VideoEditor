//
// BundledTestMediaLocator
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

import Foundation

struct BundledTestMediaLocator: BundledTestMediaLocating {

    nonisolated func url(resource: String, extension ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: resource, withExtension: ext, subdirectory: "Test Media") {
            return url
        }
        return Bundle.main.url(forResource: resource, withExtension: ext)
    }
}
