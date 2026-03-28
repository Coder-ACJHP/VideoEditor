//
//  AudioBrowseItem.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 28.03.2026.
//

import Foundation
import UIKit

struct AudioBrowseItem: Hashable {
    let id: String
    let title: String
    let artist: String
    let durationLabel: String
    let useCountLabel: String
    /// Placeholder accent for thumbnail when no artwork exists.
    let thumbTint: UIColor
    let url: URL?
}

enum AudioBrowseTab: Int, CaseIterable {
    case forYou
    case trending
    case original

    var title: String {
        switch self {
        case .forYou: return "For you"
        case .trending: return "Trending"
        case .original: return "Original audio"
        }
    }
}
