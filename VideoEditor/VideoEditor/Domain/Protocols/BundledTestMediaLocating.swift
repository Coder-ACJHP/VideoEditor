//
// BundledTestMediaLocating
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  Resolves URLs for sample assets shipped under Resources (e.g. Test Media).
//

import Foundation

protocol BundledTestMediaLocating: Sendable {
    func url(resource: String, extension ext: String) -> URL?
}
