//
//  EditImagePrivacyTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 29/08/2021.
//

import UIKit
import piwigoKit

class EditImagePrivacyTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var label: UILabel!
    @IBOutlet private weak var list: UILabel!

    override func setSelected(_ selected: Bool, animated: Bool) {
        // Configure the view for the selected state
        super.setSelected(selected, animated: animated)
    }

    func setLeftLabel(withText text: String?) {
        label.text = text
        label.textColor = .piwigoColorLeftLabel()
    }

    func setPrivacyLevel(with privacy: kPiwigoPrivacy, inColor color: UIColor?) {
        list.text = privacy.name
        list.textColor = color
    }
}
