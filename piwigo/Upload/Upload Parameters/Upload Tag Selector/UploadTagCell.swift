//
//  UploadTagCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
 
class UploadTagCell: UITableViewCell {
    
    struct tagCellOptions
    {
        enum actions {
            case none
            case add
            case remove
            case unknown
        }
    }

    @IBOutlet weak private var leftLabel: UILabel!
    @IBOutlet weak private var rightAddImage: UIImageView!
    @IBOutlet weak private var rightRemoveImage: UIImageView!
    
    // Configures the cell with a tag instance
    func configureCell(with activityName: String, action: tagCellOptions.actions) {
        
        // General settings
        backgroundColor = UIColor.piwigoCellBackground()
        tintColor = UIColor.piwigoOrange()
        textLabel?.font = UIFont.piwigoFontNormal()

        // Activity name
        leftLabel.text = activityName
        leftLabel.font = UIFont.piwigoFontNormal()
        leftLabel.textColor = UIColor.piwigoLeftLabel()

        // Change image according to state
        switch action {
        case .none:
            rightAddImage.isHidden = true;
            rightRemoveImage.isHidden = true;
            break;
                
        case .add:
            rightAddImage.isHidden = false;
            rightRemoveImage.isHidden = true;
            break;
                
        case .remove:
            rightAddImage.isHidden = true;
            rightRemoveImage.isHidden = false;
            break;
        
        case .unknown:
            // Leaves current image
            break
        }

    }
    
    override func prepareForReuse() {
        leftLabel.text = ""
    }
}
