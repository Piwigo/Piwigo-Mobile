//
//  VideoHUD.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/07/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

class VideoHUD: UIView {
    
    var status: PlayerViewControllerCoordinator.Status = [] {
        didSet {
            guard status != oldValue else { return }
//            label.setTitle(status.debugDescription, for: .normal)
            if status.contains(.externalDisplayActive) {
                label.isHidden = status.contains(.readyForDisplay)
            }
        }
    }
    
    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("loadingHUD_label", comment: "Loading…")
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.font = UIFont.systemFont(ofSize: 64)
        label.numberOfLines = 0
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        return label
    }()

//    private lazy var button: UIButton = {
//        var button: UIButton
//        var filled = UIButton.Configuration.filled()
//        filled.title = NSLocalizedString("loadingHUD_label", comment: "Loading…")
//        filled.titleAlignment = .center
//        filled.buttonSize = .medium
//        filled.baseBackgroundColor = UIColor(white: 0.0, alpha: 0.35)
//        button = UIButton(configuration: filled)
//        button.tintColor = .white
//        button.sizeToFit()
//        button.translatesAutoresizingMaskIntoConstraints = false
//        addSubview(button)
//        NSLayoutConstraint.activate([
//            button.centerXAnchor.constraint(equalTo: centerXAnchor),
//            button.centerYAnchor.constraint(equalTo: centerYAnchor)
//            ])
//        return button
//    }()
}
