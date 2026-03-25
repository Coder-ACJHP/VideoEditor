import UIKit

@MainActor
final class LoadingOverlayView: UIView {

    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    /// When true, the overlay blocks touches from reaching underlying views.
    private let blocksTouches: Bool

    init(blocksTouches: Bool = true) {
        self.blocksTouches = blocksTouches
        super.init(frame: .zero)

        isHidden = true
        alpha = 0
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = blocksTouches

        addSubview(blurView)
        addSubview(dimView)
        addSubview(indicator)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLoading(_ isLoading: Bool, animated: Bool = true) {
        if isLoading {
            isHidden = false
            indicator.startAnimating()
        }

        let animations = { [weak self] in
            guard let self else { return }
            self.alpha = isLoading ? 1 : 0
        }

        let completion: (Bool) -> Void = { [weak self] _ in
            guard let self else { return }
            if !isLoading {
                self.indicator.stopAnimating()
                self.isHidden = true
            }
        }

        guard animated else {
            animations()
            completion(true)
            return
        }

        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            animations()
        } completion: { finished in
            completion(finished)
        }
    }
}

