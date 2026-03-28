//
//  AudioWaveformStripView.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 28.03.2026.
//

import Foundation
import UIKit

// MARK: - Waveform strip

/// Renders pseudo-random bars seeded by clip id so layout stays stable while resizing.
final class AudioWaveformStripView: UIView {

    var barColor: UIColor = UIColor.black.withAlphaComponent(0.42) {
        didSet { setNeedsDisplay() }
    }

    /// Drives repeatable bar heights per clip.
    var heightSeed: UInt64 = 0 {
        didSet { setNeedsDisplay() }
    }

    private let barCornerRadius: CGFloat = 1
    private let minimumBarWidth: CGFloat = 1.5
    private let barSpacing: CGFloat = 2

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), rect.height > 2, rect.width > 4 else { return }

        let unit = minimumBarWidth + barSpacing
        let count = max(6, Int(floor(rect.width / unit)))
        let totalSpacing = CGFloat(count - 1) * barSpacing
        let barW = max(minimumBarWidth, (rect.width - totalSpacing) / CGFloat(count))
        var x = CGFloat(0)
        let midY = rect.midY

        for i in 0..<count {
            let t = heightMultiplier(index: i, total: count)
            let barH = max(3, rect.height * t)
            let barRect = CGRect(
                x: x,
                y: midY - barH / 2,
                width: barW,
                height: barH
            )
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: barCornerRadius)
            ctx.setFillColor(barColor.cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            x += barW + barSpacing
        }
    }

    private func heightMultiplier(index: Int, total: Int) -> CGFloat {
        let state = heightSeed &+ UInt64(index &* 1103515245 &+ 12345)
        let u01 = Double(state % 10_000) / 10_000.0
        let wave = 0.5 + 0.45 * sin(Double(index) * 0.65 + Double(heightSeed % 97) * 0.1)
        let mixed = (wave + u01) / 2
        return CGFloat(0.22 + mixed * 0.68)
    }
}
