//
//  PadTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/07/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

class PadTableViewCell: UITableViewCell {
    
    @IBOutlet weak var lightImage: UIButton!
    @IBOutlet weak var lightLabel: UIButton!
    @IBOutlet weak var lightLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var lightButton: UIButton!
    
    @IBOutlet weak var darkImage: UIButton!
    @IBOutlet weak var darkLabel: UIButton!
    @IBOutlet weak var darkLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var darkButton: UIButton!
    
    func configure() {
        // iPad — light mode
        guard let lightUrl = Bundle.main.url(forResource: "lightPad", withExtension: "png")
        else { preconditionFailure("!!! Could not find lightPad image !!!") }
        lightImage.layoutIfNeeded() // Ensure buttonView is in its final size.
        var scale = max(lightImage.traitCollection.displayScale, 1.0)
        var cellSize = CGSizeMake(lightImage.bounds.size.width * scale, lightImage.bounds.size.height * scale)
        lightImage.setImage(ImageUtilities.downsample(imageAt: lightUrl, to: cellSize, for: .image), for: .normal)
        
        // iPad - dark mode
        guard let darkUrl = Bundle.main.url(forResource: "darkPad", withExtension: "png")
        else { preconditionFailure("!!! Could not find darkPad image !!!") }
        darkImage.layoutIfNeeded() // Ensure buttonView is in its final size.
        scale = darkImage.traitCollection.displayScale
        cellSize = CGSizeMake(darkImage.bounds.size.width * scale, darkImage.bounds.size.height * scale)
        darkImage.setImage(ImageUtilities.downsample(imageAt: darkUrl, to: cellSize, for: .image), for: .normal)

        // Labels
        let labelHeight = UIFont.preferredFont(forTextStyle: .footnote).pointSize + TableViewUtilities.defaultVertMargin
        lightLabel.setTitle(NSLocalizedString("settings_lightColor", comment: "Light"), for: .normal)
        lightLabel.setTitleColor(PwgColor.leftLabel, for: .normal)
        lightLabelHeight.constant = labelHeight
        darkLabel.setTitle(NSLocalizedString("settings_darkColor", comment: "Dark"), for: .normal)
        darkLabel.setTitleColor(PwgColor.leftLabel, for: .normal)
        darkLabelHeight.constant = labelHeight

        // Buttons
        let config = UIImage.SymbolConfiguration(pointSize: labelHeight / 2.0, weight: .semibold)
        if AppVars.shared.isDarkPaletteActive {
            lightButton.setImage(UIImage(systemName: "circle", withConfiguration: config), for: .normal)
            lightButton.imageView?.tintColor = PwgColor.rightLabel
            darkButton.setImage(UIImage(systemName: "checkmark.circle.fill", withConfiguration: config), for: .normal)
            darkButton.imageView?.tintColor = PwgColor.orange
        } else {
            lightButton.setImage(UIImage(systemName: "checkmark.circle.fill", withConfiguration: config), for: .normal)
            lightButton.imageView?.tintColor = PwgColor.orange
            darkButton.setImage(UIImage(systemName: "circle", withConfiguration: config), for: .normal)
            darkButton.imageView?.tintColor = PwgColor.rightLabel
        }
    }
        
    @IBAction func didTapLightMode(_ sender: Any) {
        // Select static light mode
        AppVars.shared.isLightPaletteModeActive = true
        AppVars.shared.isDarkPaletteModeActive = false
        AppVars.shared.switchPaletteAutomatically = false

        // Apply light color palette
        (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()
        
        // Update button
        lightButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        darkButton.setImage(UIImage(systemName: "circle"), for: .normal)
    }
    
    @IBAction func didTapDarkMode(_ sender: Any) {
        // Select static dark mode
        AppVars.shared.isLightPaletteModeActive = false
        AppVars.shared.isDarkPaletteModeActive = true
        AppVars.shared.switchPaletteAutomatically = false

        // Apply dark color palette
        (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()
        
        // Update button
        lightButton.setImage(UIImage(systemName: "circle"), for: .normal)
        darkButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
    }
}
