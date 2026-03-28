//
//  UIFont+Extension.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 28.03.2026.
//

import Foundation
import UIKit

extension UIFont {

    func addingSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let d = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: d, size: 0)
    }
}
