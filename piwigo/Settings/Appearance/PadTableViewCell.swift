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
    @IBOutlet weak var lightButton: UIButton!
    
    @IBOutlet weak var darkImage: UIButton!
    @IBOutlet weak var darkLabel: UIButton!
    @IBOutlet weak var darkButton: UIButton!
    
    func configure() {
        // iPad — light mode
        guard let lightUrl = Bundle.main.url(forResource: "lightPad", withExtension: "png") else {
            fatalError("!!! Could not find lightPad image !!!")
        }
        lightImage.layoutIfNeeded() // Ensure buttonView is in its final size.
        var size = lightImage.bounds.size
        var scale = lightImage.traitCollection.displayScale
        lightImage.setImage(ImageUtilities.downsample(imageAt: lightUrl, to: size, scale: scale), for: .normal)
        lightImage.layer.cornerRadius = 5
        
        // iPad - dark mode
        guard let darkUrl = Bundle.main.url(forResource: "darkPad", withExtension: "png") else {
            fatalError("!!! Could not find darkPad image !!!")
        }
        darkImage.layoutIfNeeded() // Ensure buttonView is in its final size.
        size = darkImage.bounds.size
        scale = darkImage.traitCollection.displayScale
        darkImage.setImage(ImageUtilities.downsample(imageAt: darkUrl, to: size, scale: scale), for: .normal)
        darkImage.layer.cornerRadius = 5

        // Labels
        lightLabel.setTitle(NSLocalizedString("settings_lightColor", comment: "Light"), for: .normal)
        lightLabel.setTitleColor(.piwigoColorLeftLabel(), for: .normal)
        darkLabel.setTitle(NSLocalizedString("settings_darkColor", comment: "Dark"), for: .normal)
        darkLabel.setTitleColor(.piwigoColorLeftLabel(), for: .normal)
        
        // Buttons
        if #available(iOS 13.0, *) {
            if AppVars.shared.isDarkPaletteActive {
                lightButton.setImage(UIImage(systemName: "circle"), for: .normal)
                lightButton.tintColor = .piwigoColorRightLabel()
                darkButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                darkButton.tintColor = .piwigoColorOrange()
            } else {
                lightButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                lightButton.tintColor = .piwigoColorOrange()
                darkButton.setImage(UIImage(systemName: "circle"), for: .normal)
                darkButton.tintColor = .piwigoColorRightLabel()
            }
        } else {
            // Fallback on earlier versions
            if AppVars.shared.isDarkPaletteActive {
                lightButton.setImage(UIImage(named: "circle"), for: .normal)
                lightButton.tintColor = .piwigoColorRightLabel()
                darkButton.setImage(UIImage(named: "checkmark.circle.fill"), for: .normal)
                darkButton.tintColor = .piwigoColorOrange()
            } else {
                lightButton.setImage(UIImage(named: "checkmark.circle.fill"), for: .normal)
                lightButton.tintColor = .piwigoColorOrange()
                darkButton.setImage(UIImage(named: "circle"), for: .normal)
                darkButton.tintColor = .piwigoColorRightLabel()
            }
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
        if #available(iOS 13.0, *) {
            lightButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
            darkButton.setImage(UIImage(systemName: "circle"), for: .normal)
        } else {
            // Fallback on earlier versions
            lightButton.setImage(UIImage(named: "checkmark.circle.fill"), for: .normal)
            darkButton.setImage(UIImage(named: "circle"), for: .normal)
        }
    }
    
    @IBAction func didTapDarkMode(_ sender: Any) {
        // Select static dark mode
        AppVars.shared.isLightPaletteModeActive = false
        AppVars.shared.isDarkPaletteModeActive = true
        AppVars.shared.switchPaletteAutomatically = false

        // Apply dark color palette
        (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()
        
        // Update button
        if #available(iOS 13.0, *) {
            lightButton.setImage(UIImage(systemName: "circle"), for: .normal)
            darkButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        } else {
            // Fallback on earlier versions
            lightButton.setImage(UIImage(named: "circle"), for: .normal)
            darkButton.setImage(UIImage(named: "checkmark.circle.fill"), for: .normal)
        }
    }
}
