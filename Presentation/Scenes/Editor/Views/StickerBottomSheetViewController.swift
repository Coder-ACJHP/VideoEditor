//
//  StickerBottomSheetViewController.swift
//  VideoEditor
//
//  Created by Coder ACJHP on 27.03.2026.
//

import UIKit

class StickerBottomSheetViewController: UIViewController {

    private let router: AppRouter
    
    init(router: AppRouter!) {
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .red
        navigationItem.title = "Add Sticker"
    }
}
