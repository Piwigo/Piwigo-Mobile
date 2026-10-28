//
//  MetadataCardView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Card floating over the photo on iPad, presenting the metadata table.
//

import UIKit
import PwgKit
import PwgUIKit

/// Card floating over the photo, presenting the metadata table below a title and a close button.
/// The user drags the card by its title or its grabber, and it settles in the nearest corner.
final class MetadataCardView: UIView, UIGestureRecognizerDelegate
{
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    // MARK: - Dimensions
    static let width: CGFloat = pwgPadSubViewWidth
    static let headerHeight: CGFloat = 56
    static let footerHeight: CGFloat = 24
    static func preferredHeight(contentHeight: CGFloat) -> CGFloat {
        return headerHeight + contentHeight + footerHeight
    }
    
    // MARK: - Views
    var onClose: (() -> Void)?
    let panGesture = UIPanGestureRecognizer()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let grabber = UIView()
    
    // MARK: - Initialisation
    init(contentView: UIView) {
        super.init(frame: .zero)
        
        // Shadow, around a view clipping its content to rounded corners
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)
        accessibilityIdentifier = "ImageMetadataCard"
        
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 24
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true
        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // Title
        titleLabel.text = String(localized: "imageInfo_title", comment: "Information")
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = PwgColor.leftLabel
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.accessibilityTraits = .header
        
        // Close button
        closeButton.setImage(UIImage(systemName: "xmark",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)),
                             for: .normal)
        closeButton.tintColor = PwgColor.leftLabel
        closeButton.accessibilityLabel = Localized.dismiss
        closeButton.accessibilityIdentifier = "closeMetadata"
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Grabber
        grabber.backgroundColor = PwgColor.rightLabel.withAlphaComponent(0.6)
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        
        // Table
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        let container = effectView.contentView
        container.addSubview(contentView)
        container.addSubview(titleLabel)
        container.addSubview(closeButton)
        container.addSubview(grabber)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: container.topAnchor, constant: Self.headerHeight / 2 + 4),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            contentView.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.headerHeight),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.footerHeight),
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grabber.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5)
        ])
        
        // The card is dragged by its title and its grabber, not by the table
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        // Colors follow the palette of the app
        applyColorPalette()
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // The palette of the app is independent from the appearance of the system:
        /// the material, the label colors and the map in the table adopt that of the palette.
        overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        titleLabel.textColor = PwgColor.leftLabel
        closeButton.tintColor = PwgColor.leftLabel
        grabber.backgroundColor = PwgColor.rightLabel.withAlphaComponent(0.6)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 24).cgPath
    }
    
    // MARK: - Actions
    @objc private func didTapClose() {
        onClose?()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let y = touch.location(in: self).y
        return y < Self.headerHeight || y > bounds.height - Self.footerHeight
    }
}
