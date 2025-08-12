//
//  PhoneTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

class PhoneTableViewCell: UITableViewCell {
    
    @IBOutlet weak var lightImage: UIButton!
    @IBOutlet weak var lightLabel: UIButton!
    @IBOutlet weak var lightButton: UIButton!
    
    @IBOutlet weak var darkImage: UIButton!
    @IBOutlet weak var darkLabel: UIButton!
    @IBOutlet weak var darkButton: UIButton!
    
    func configure() {
        // iPhone — light mode
        guard let lightUrl = Bundle.main.url(forResource: "lightPhone", withExtension: "png") else {
            fatalError("!!! Could not find lightPhone image !!!")
        }
        lightImage.layoutIfNeeded() // Ensure buttonView is in its final size.
        var scale = max(lightImage.traitCollection.displayScale, 1.0)
        var cellSize = CGSizeMake(lightImage.bounds.size.width * scale, lightImage.bounds.size.height * scale)
        lightImage.setImage(ImageUtilities.downsample(imageAt: lightUrl, to: cellSize, for: .image), for: .normal)

        // iPhone - dark mode
        guard let darkUrl = Bundle.main.url(forResource: "darkPhone", withExtension: "png") else {
            fatalError("!!! Could not find darkPhone image !!!")
        }
        darkImage.layoutIfNeeded() // Ensure buttonView is in its final size.
        scale = darkImage.traitCollection.displayScale
        cellSize = CGSizeMake(darkImage.bounds.size.width * scale, darkImage.bounds.size.height * scale)
        darkImage.setImage(ImageUtilities.downsample(imageAt: darkUrl, to: cellSize, for: .image), for: .normal)

        // Labels
        lightLabel.setTitle(NSLocalizedString("settings_lightColor", comment: "Light"), for: .normal)
        lightLabel.setTitleColor(.piwigoColorLeftLabel(), for: .normal)
        darkLabel.setTitle(NSLocalizedString("settings_darkColor", comment: "Dark"), for: .normal)
        darkLabel.setTitleColor(.piwigoColorLeftLabel(), for: .normal)
        
        // Buttons
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
    }
        
    @IBAction func didTapLightMode(_ sender: Any) {
        // Select static light mode
        AppVars.shared.isLightPaletteModeActive = true
        AppVars.shared.isDarkPaletteModeActive = false
        AppVars.shared.switchPaletteAutomatically = false

        // Apply light color palette
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.screenBrightnessChanged()

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
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.screenBrightnessChanged()

        // Update button
        lightButton.setImage(UIImage(systemName: "circle"), for: .normal)
        darkButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
    }
}
