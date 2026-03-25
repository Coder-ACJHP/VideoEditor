//
//  ProjectCell.swift
//  VideoEditor
//
//  Responsibilities (only these):
//  • Lay out and display project card UI (thumbnail, title, meta line).
//  • Cancel any in-flight thumbnail task when reused.
//
//  What this file does NOT do:
//  • No AVFoundation / image decoding — delegated to ThumbnailGenerating.
//  • No date or byte-size arithmetic — delegated to RelativeDateFormatter /
//    FileSizeFormatter.
//  • No domain-model queries beyond what configure(with:) receives.

import UIKit

final class ProjectCell: UICollectionViewCell {

    static let reuseIdentifier = "ProjectCell"

    // MARK: - Subviews

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        iv.layer.cornerCurve = .continuous
        iv.backgroundColor = .tertiarySystemGroupedBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - State

    private var thumbnailTask: Task<Void, Never>?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        thumbnailImageView.image = nil
        thumbnailImageView.tintColor = nil
        titleLabel.text = nil
        metaLabel.text = nil
    }

    // MARK: - Configuration

    /// Configures the cell with an `EditingProject` and an injected thumbnail service.
    ///
    /// - Parameters:
    ///   - project:          Domain model providing all display data.
    ///   - thumbnailService: Service responsible for async thumbnail generation and caching.
    ///                       Injected so the cell remains testable and the service is shared
    ///                       across the collection (single cache, no duplicate work).
    func configure(with project: EditingProject, thumbnailService: ThumbnailGenerating) {
        titleLabel.text = project.name
        metaLabel.text = "\(RelativeDateFormatter.string(from: project.creationDate)) • \(FileSizeFormatter.string(fromByteCount: project.totalByteSize))"
        loadThumbnail(asset: project.firstAssetIdentifier, using: thumbnailService)
    }

    // MARK: - Private

    private func setupLayout() {
        contentView.backgroundColor = .clear
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(metaLabel)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 176),

            titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),

            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }

    private func loadThumbnail(asset: AssetIdentifier?, using service: ThumbnailGenerating) {
        guard let asset else {
            setPlaceholder()
            return
        }

        thumbnailTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Defer size resolution until layout has occurred; fall back to a
            // reasonable default if the cell hasn't been laid out yet.
            let bounds = thumbnailImageView.bounds
            let scale  = UIScreen.main.scale
            let size   = bounds.width > 0
                ? CGSize(width: bounds.width * scale, height: bounds.height * scale)
                : CGSize(width: 900, height: 900)

            let image = await service.thumbnail(for: asset, size: size)
            guard !Task.isCancelled else { return }

            if let image {
                thumbnailImageView.image = image
                thumbnailImageView.tintColor = nil
            } else {
                setPlaceholder()
            }
        }
    }

    private func setPlaceholder() {
        thumbnailImageView.image = UIImage(systemName: "photo")
        thumbnailImageView.tintColor = .secondaryLabel
    }
}
