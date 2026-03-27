//
//  TextTrackMediaView.swift
//  VideoEditor
//

import UIKit

final class TextTrackMediaView: TrackMediaView {
    private let label = UILabel()

    override func setupMediaContent() {
        contentView.backgroundColor = TimelineConfiguration.default.textTrackColor
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.text = "Text"
        contentView.addSubview(label)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds.insetBy(dx: 8, dy: 8)
    }
}
