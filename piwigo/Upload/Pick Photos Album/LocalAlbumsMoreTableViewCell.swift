//
//  LocalAlbumsMoreTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit

class LocalAlbumsMoreTableViewCell: UITableViewCell {

    @IBOutlet weak var moreImage: UIImageView!
    
    func configure() {
        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()
        moreImage.tintColor = UIColor.piwigoColorRightLabel()
    }
}
