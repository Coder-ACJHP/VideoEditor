//
//  LandingViewController.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 25.03.2026.
//

import UIKit

class LandingViewController: UIViewController {
    
    private let router: AppRouter
    
    init(router: AppRouter) {
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Subviews

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Video Editor"
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.title = "Landing"
        navigationItem.largeTitleDisplayMode = .always
        setupNavigationBar()
        addMediaPickerButton()
        setupPlaceholderLabel()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        // prefersLargeTitles must be set on the UINavigationController, not the item.
        // viewDidLoad is called after the VC is added to the hierarchy, so
        // navigationController is already non-nil at this point.
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func setupPlaceholderLabel() {
        view.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func addMediaPickerButton() {
        let action = #selector(addMediaButtonAction)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: action
        )
    }

    // MARK: - Actions

    @objc
    private func addMediaButtonAction() {

    }
}

