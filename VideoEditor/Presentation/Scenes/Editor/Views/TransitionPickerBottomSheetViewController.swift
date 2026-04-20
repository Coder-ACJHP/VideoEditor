//
// TransitionPickerBottomSheetViewController
// VideoEditor
//  Created by Coder ACJHP on 27.03.2026.

//  System-styled sheet: grid of transition types (3 columns), square rounded previews + labels.
//

import UIKit

@MainActor
final class TransitionPickerBottomSheetViewController: UIViewController {

    private let allTypes = ClipTransition.TransitionType.allCases
    private let currentTransition: ClipTransition?
    private let onCommit: (ClipTransition?) -> Void

    private let flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 4, left: 0, bottom: 16, right: 0)
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.register(TransitionPickerCell.self, forCellWithReuseIdentifier: TransitionPickerCell.reuseId)
        cv.dataSource = self
        cv.delegate = self
        cv.accessibilityIdentifier = "transitionPicker.collection"
        return cv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "Transition")
        label.font = UIFont.preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.accessibilityTraits.insert(.header)
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "Applied between this clip and the next.")
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    /// Ensures we scroll after the sheet + collection have a real width.
    private var didScrollToCurrentSelection = false

    init(currentTransition: ClipTransition?, onCommit: @escaping (ClipTransition?) -> Void) {
        self.currentTransition = currentTransition
        self.onCommit = onCommit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, collectionView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(6, after: titleLabel)

        view.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToCurrentSelectionIfNeeded(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if collectionView.bounds.width > 0 {
            scrollToCurrentSelectionIfNeeded()
        }
    }

    private func scrollToCurrentSelectionIfNeeded(animated: Bool = false) {
        guard !didScrollToCurrentSelection,
              let type = currentTransition?.type,
              let idx = allTypes.firstIndex(of: type)
        else { return }
        guard collectionView.bounds.width > 0 else { return }

        collectionView.layoutIfNeeded()
        let indexPath = IndexPath(item: idx, section: 0)
        guard indexPath.item < collectionView.numberOfItems(inSection: 0) else { return }

        let task = { self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated) }
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { task() }
        } else {
            task()
        }
        didScrollToCurrentSelection = true
    }

    private func itemColumnWidth(in collectionView: UICollectionView) -> CGFloat {
        let columns: CGFloat = 3
        let inset = flowLayout.sectionInset.left + flowLayout.sectionInset.right
        let interGap = flowLayout.minimumInteritemSpacing * (columns - 1)
        let total = collectionView.bounds.width - inset - interGap
        return floor(total / columns)
    }

    /// Vertical space between thumbnail bottom and label top (not flush).
    fileprivate static var thumbnailToLabelGap: CGFloat { 12 }

    /// Reserve two lines of caption so every row has the same height.
    fileprivate static func labelBlockHeight() -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .caption1)
        let line = font.lineHeight
        return ceil(line * 2)
    }

    private func commitAndDismiss(with transition: ClipTransition?) {
        onCommit(transition)
        dismiss(animated: true)
    }
}

// MARK: - Collection

extension TransitionPickerBottomSheetViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        allTypes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TransitionPickerCell.reuseId,
            for: indexPath
        ) as? TransitionPickerCell else {
            return UICollectionViewCell()
        }
        let type = allTypes[indexPath.item]
        let selected = currentTransition?.type == type
        cell.configure(
            type: type,
            isSelected: selected,
            onRemoveTapped: selected ? { [weak self] in
                self?.commitAndDismiss(with: nil)
            } : nil
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let type = allTypes[indexPath.item]
        let next = ClipTransition(type: type, durationSeconds: ClipTransition.default.durationSeconds)
        commitAndDismiss(with: next)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let w = itemColumnWidth(in: collectionView)
        let h = w + Self.thumbnailToLabelGap + Self.labelBlockHeight()
        return CGSize(width: w, height: h)
    }
}

// MARK: - Cell

private final class TransitionPickerCell: UICollectionViewCell {

    static let reuseId = "TransitionPickerCell"

    private let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.clipsToBounds = true
        iv.layer.cornerCurve = .continuous
        iv.layer.cornerRadius = 8
        iv.backgroundColor = .secondarySystemFill
        iv.tintColor = .label
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var removeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        config.image = UIImage(systemName: "trash.fill")
        config.baseForegroundColor = .systemRed
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = String(localized: "Remove transition")
        button.addAction(UIAction { [weak self] _ in
            self?.onRemoveTapped?()
        }, for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private var onRemoveTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(previewImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(removeButton)

        let labelHeight = TransitionPickerBottomSheetViewController.labelBlockHeight()
        let thumbToLabel = TransitionPickerBottomSheetViewController.thumbnailToLabelGap

        NSLayoutConstraint.activate([
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewImageView.heightAnchor.constraint(equalTo: previewImageView.widthAnchor),

            nameLabel.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: thumbToLabel),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            nameLabel.heightAnchor.constraint(equalToConstant: labelHeight),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            removeButton.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 8),
            removeButton.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.bringSubviewToFront(removeButton)
        contentView.bringSubviewToFront(nameLabel)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onRemoveTapped = nil
        removeButton.isHidden = true
    }

    func configure(
        type: ClipTransition.TransitionType,
        isSelected: Bool,
        onRemoveTapped: (() -> Void)?
    ) {
        self.onRemoveTapped = onRemoveTapped
        nameLabel.text = type.editorDisplayName
        accessibilityLabel = type.editorDisplayName

        if let asset = type.editorPreviewAssetImage {
            previewImageView.image = asset
            previewImageView.contentMode = .scaleAspectFill
            previewImageView.preferredSymbolConfiguration = nil
        } else {
            let sym = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            previewImageView.image = UIImage(systemName: type.editorPreviewSymbolName, withConfiguration: sym)?
                .withTintColor(.label, renderingMode: .alwaysOriginal)
            previewImageView.contentMode = .center
        }

        updateSelectionState(isSelected)
    }

    private func updateSelectionState(_ isSelected: Bool) {
        previewImageView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : nil
        previewImageView.layer.borderWidth = isSelected ? 2.0 : 0.0
        removeButton.isHidden = !isSelected
        removeButton.isUserInteractionEnabled = isSelected
    }
}
