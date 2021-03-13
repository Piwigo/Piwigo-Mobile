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
            lightImage.setImage(UIImage.init(named: "lightPhone"), for: .normal)
            lightImage.layer.cornerRadius = 8
            darkImage.setImage(UIImage.init(named: "darkPhone"), for: .normal)
            darkImage.layer.cornerRadius = 8
        } else {
            lightImage.setImage(UIImage.init(named: "lightPad"), for: .normal)
            lightImage.layer.cornerRadius = 5
            darkImage.setImage(UIImage.init(named: "darkPad"), for: .normal)
            darkImage.layer.cornerRadius = 5
        }

        // Labels
        lightLabel.setTitle(NSLocalizedString("settings_lightColor", comment: "Light"), for: .normal)
        lightLabel.setTitleColor(UIColor.piwigoColorLeftLabel(), for: .normal)
        darkLabel.setTitle(NSLocalizedString("settings_darkColor", comment: "Dark"), for: .normal)
        darkLabel.setTitleColor(UIColor.piwigoColorLeftLabel(), for: .normal)
        
        // Buttons
        if #available(iOS 13.0, *) {
            if Model.sharedInstance()?.isDarkPaletteActive ?? false {
                lightButton.setImage(UIImage.init(systemName: "circle"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorRightLabel()
                darkButton.setImage(UIImage.init(systemName: "checkmark.circle.fill"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorOrange()
            } else {
                lightButton.setImage(UIImage.init(systemName: "checkmark.circle.fill"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorOrange()
                darkButton.setImage(UIImage.init(systemName: "circle"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorRightLabel()
            }
        } else {
            // Fallback on earlier versions
            if Model.sharedInstance()?.isDarkPaletteActive ?? false {
                lightButton.setImage(UIImage.init(named: "circle"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorRightLabel()
                darkButton.setImage(UIImage.init(named: "checkmark.circle.fill"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorOrange()
            } else {
                lightButton.setImage(UIImage.init(named: "checkmark.circle.fill"), for: .normal)
                lightButton.tintColor = UIColor.piwigoColorOrange()
                darkButton.setImage(UIImage.init(named: "circle"), for: .normal)
                darkButton.tintColor = UIColor.piwigoColorRightLabel()
            }
        }
    }
        
    @IBAction func didTapLightMode(_ sender: Any) {
        // Select static light mode
        Model.sharedInstance()?.isLightPaletteModeActive = true
        Model.sharedInstance()?.isDarkPaletteModeActive = false
        Model.sharedInstance()?.switchPaletteAutomatically = false
        Model.sharedInstance()?.saveToDisk()

        // Apply light color palette
        (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()
        
        // Update button
        if #available(iOS 13.0, *) {
            lightButton.setImage(UIImage.init(systemName: "checkmark.circle.fill"), for: .normal)
            darkButton.setImage(UIImage.init(systemName: "circle"), for: .normal)
        } else {
            // Fallback on earlier versions
            lightButton.setImage(UIImage.init(named: "checkmark.circle.fill"), for: .normal)
            darkButton.setImage(UIImage.init(named: "circle"), for: .normal)
        }
    }
    
    @IBAction func didTapDarkMode(_ sender: Any) {
        // Select static dark mode
        Model.sharedInstance()?.isLightPaletteModeActive = false
        Model.sharedInstance()?.isDarkPaletteModeActive = true
        Model.sharedInstance()?.switchPaletteAutomatically = false
        Model.sharedInstance()?.saveToDisk()

        // Apply dark color palette
        (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()
        
        // Update button
        if #available(iOS 13.0, *) {
            lightButton.setImage(UIImage.init(systemName: "circle"), for: .normal)
            darkButton.setImage(UIImage.init(systemName: "checkmark.circle.fill"), for: .normal)
        } else {
            // Fallback on earlier versions
            lightButton.setImage(UIImage.init(named: "circle"), for: .normal)
            darkButton.setImage(UIImage.init(named: "checkmark.circle.fill"), for: .normal)
        }
    }
}
