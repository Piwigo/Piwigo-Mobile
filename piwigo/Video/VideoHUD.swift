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
            if status.contains(.embeddedInline) {
                button.isHidden = status.contains(.readyForDisplay)
            } else if status.contains(.externalDisplayActive) {
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

    private lazy var button: UIButton = {
        var button: UIButton
        if #available(iOS 15, *) {
            var filled = UIButton.Configuration.filled()
            filled.title = NSLocalizedString("loadingHUD_label", comment: "Loading…")
            filled.titleAlignment = .center
            filled.buttonSize = .medium
            filled.baseBackgroundColor = UIColor(white: 0.0, alpha: 0.35)
            button = UIButton(configuration: filled)
            button.tintColor = .white
        } else {
            // Fallback to previous version
            button = UIButton(type: .custom)
            button.frame = CGRect(x: 0, y: 0, width: 100, height: 30)
            button.layer.cornerRadius = 5
            button.layer.masksToBounds = false
            button.layer.opacity = 0.0
            button.layer.shadowOpacity = 0.8
            button.setTitle(" " + NSLocalizedString("loadingHUD_label", comment: "Loading…") + " ", for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor(white: 0.0, alpha: 0.35)
            button.setNeedsLayout()
        }
        button.sizeToFit()
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        return button
    }()
}
