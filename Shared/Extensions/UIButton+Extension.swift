//
//  UIButton+Extension.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 25.03.2026.
//

import UIKit
import Foundation

extension UIButton {
    
    func dropOuterShadow(withColor color: UIColor, radius: CGFloat, opacity: Float = 1.0, offset: CGSize) {
        self.layer.masksToBounds = false
        self.layer.shadowOffset = offset
        self.layer.shadowOpacity = opacity
        self.layer.shadowRadius = radius
        self.layer.shadowColor = color.cgColor
        self.layer.rasterizationScale = UIScreen.main.scale
        self.layer.shouldRasterize = true
    }
    
    func addDefaultAnimation() {
        // Default iOS 15 and earlier press animation
        self.configurationUpdateHandler = { button in
            let isHighlighted = button.isHighlighted
            UIView.animate(withDuration: 0.25) {
                button.transform = isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
                button.alpha = isHighlighted ? 0.7 : 1.0
            }
        }
    }
}
