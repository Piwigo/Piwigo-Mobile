//
//  DeviceTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

class DeviceTableViewCell: UITableViewCell {
    
    @IBOutlet weak var lightImage: UIButton!
    @IBOutlet weak var lightLabel: UIButton!
    @IBOutlet weak var lightButton: UIButton!
    
    @IBOutlet weak var darkImage: UIButton!
    @IBOutlet weak var darkLabel: UIButton!
    @IBOutlet weak var darkButton: UIButton!
    
    func configure() {
        // Images
        if UIDevice.current.userInterfaceIdiom == .phone {
            lightImage.setImage(UIImage(named: "lightPhone"), for: .normal)
            lightImage.layer.cornerRadius = 8
            darkImage.setImage(UIImage(named: "darkPhone"), for: .normal)
            darkImage.layer.cornerRadius = 8
        } else {
            lightImage.setImage(UIImage(named: "lightPad"), for: .normal)
            lightImage.layer.cornerRadius = 5
            darkImage.setImage(UIImage(named: "darkPad"), for: .normal)
            darkImage.layer.cornerRadius = 5
        }

        // Labels
        lightLabel.setTitle(NSLocalizedString("settings_lightColor", comment: "Light"), for: .normal)
        lightLabel.setTitleColor(UIColor.piwigoColorLeftLabel(), for: .normal)
        darkLabel.setTitle(NSLocalizedString("settings_darkColor", comment: "Dark"), for: .normal)
        darkLabel.setTitleColor(UIColor.piwigoColorLeftLabel(), for: .normal)
        
        // Buttons
        if #available(iOS 13.0, *) {
            if AppVars.isDarkPaletteActive {
                lightButton.setImage(UIImage(systemName: "circle"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorRightLabel()
                darkButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorOrange()
            } else {
                lightButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorOrange()
                darkButton.setImage(UIImage(systemName: "circle"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorRightLabel()
            }
        } else {
            // Fallback on earlier versions
            if AppVars.isDarkPaletteActive {
                lightButton.setImage(UIImage(named: "circle"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorRightLabel()
                darkButton.setImage(UIImage(named: "checkmark.circle.fill"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorOrange()
            } else {
                lightButton.setImage(UIImage(named: "checkmark.circle.fill"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorOrange()
                darkButton.setImage(UIImage(named: "circle"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorRightLabel()
            }
        }
    }
        
    @IBAction func didTapLightMode(_ sender: Any) {
        // Select static light mode
        AppVars.isLightPaletteModeActive = true
        AppVars.isDarkPaletteModeActive = false
        AppVars.switchPaletteAutomatically = false

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
        AppVars.isLightPaletteModeActive = false
        AppVars.isDarkPaletteModeActive = true
        AppVars.switchPaletteAutomatically = false

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
