//
//  AudioTrackTableViewCell.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 28.03.2026.
//

import Foundation
import UIKit

final class AudioTrackTableViewCell: UITableViewCell {

    static let reuseId = "AudioTrackTableViewCell"

    private let thumbContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 8
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()

    private let thumbIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white.withAlphaComponent(0.85)
        iv.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        iv.image = UIImage(systemName: "music.note")
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont.preferredFont(forTextStyle: .headline)
        l.textColor = AudioSheetPalette.primaryText
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let artistLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont.preferredFont(forTextStyle: .subheadline)
        l.textColor = AudioSheetPalette.secondaryText
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let statsLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont.preferredFont(forTextStyle: .caption1)
        l.textColor = AudioSheetPalette.tertiaryText
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none


        contentView.addSubview(thumbContainer)
        thumbContainer.addSubview(thumbIcon)
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(statsLabel)

        let thumbSize: CGFloat = 56
        NSLayoutConstraint.activate([
            thumbContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbContainer.widthAnchor.constraint(equalToConstant: thumbSize),
            thumbContainer.heightAnchor.constraint(equalToConstant: thumbSize),

            thumbIcon.centerXAnchor.constraint(equalTo: thumbContainer.centerXAnchor),
            thumbIcon.centerYAnchor.constraint(equalTo: thumbContainer.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: thumbContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            statsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statsLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            statsLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 4),
            statsLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: AudioBrowseItem) {
        titleLabel.text = item.title
        artistLabel.text = item.artist
        thumbContainer.backgroundColor = item.thumbTint
        let arrow = UIImage(systemName: "arrow.up.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        let attachment = NSTextAttachment(image: arrow ?? UIImage())
        attachment.bounds = CGRect(x: 0, y: -1, width: 12, height: 12)
        let attr = NSMutableAttributedString(attachment: attachment)
        attr.append(NSAttributedString(string: " \(item.useCountLabel) · \(item.durationLabel)"))
        attr.addAttribute(.foregroundColor, value: AudioSheetPalette.tertiaryText, range: NSRange(location: 0, length: attr.length))
        attr.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .caption1), range: NSRange(location: 0, length: attr.length))
        statsLabel.attributedText = attr
    }
}
