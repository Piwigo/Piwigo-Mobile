//
//  LabelTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 2/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import UIKit

class LabelTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    
    func configure(with title: String, detail: String) -> Void {

        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()

        // Left side: title
        titleLabel.font = .piwigoFontNormal()
        titleLabel.textColor = .piwigoColorLeftLabel()
        titleLabel.text = title
        
        // Right side: detail
        detailLabel.font = .piwigoFontNormal()
        detailLabel.textColor = .piwigoColorRightLabel()
        detailLabel.text = detail
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        detailLabel.text = ""
    }
}
