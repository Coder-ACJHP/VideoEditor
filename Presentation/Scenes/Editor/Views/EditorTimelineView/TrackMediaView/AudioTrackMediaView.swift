//
//  AudioTrackMediaView.swift
//  VideoEditor
//

import UIKit

final class AudioTrackMediaView: TrackMediaView {

    private let barsContainer = UIStackView()

    override init(frame: CGRect, clip: MediaClip, layout: TimelineLayoutProvider) {
        super.init(frame: frame, clip: clip, layout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupMediaContent() {
        contentView.backgroundColor = TimelineConfiguration.default.audioTrackColor
        barsContainer.axis = .horizontal
        barsContainer.alignment = .center
        barsContainer.distribution = .fillEqually
        barsContainer.spacing = 2
        contentView.addSubview(barsContainer)
        buildWaveform()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        barsContainer.frame = contentView.bounds.insetBy(dx: 6, dy: 6)
    }

    private func buildWaveform() {
        let heights: [CGFloat] = [0.25, 0.55, 0.35, 0.75, 0.45, 0.62, 0.30, 0.70, 0.40, 0.58, 0.33]
        heights.forEach { h in
            let barContainer = UIView()
            let bar = UIView()
            bar.backgroundColor = UIColor.white.withAlphaComponent(0.85)
            bar.layer.cornerRadius = 1
            bar.translatesAutoresizingMaskIntoConstraints = false
            barContainer.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.centerXAnchor.constraint(equalTo: barContainer.centerXAnchor),
                bar.centerYAnchor.constraint(equalTo: barContainer.centerYAnchor),
                bar.widthAnchor.constraint(equalToConstant: 2.2),
                bar.heightAnchor.constraint(equalTo: barContainer.heightAnchor, multiplier: h),
            ])
            barsContainer.addArrangedSubview(barContainer)
        }
    }
}
