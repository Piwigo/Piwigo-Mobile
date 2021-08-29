//
//  EditImageTagsTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 29/08/2021.
//

import UIKit

@objc
class EditImageTagsTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var tagsLabel: UILabel!
    @IBOutlet private weak var tagsList: UILabel!

    private var _tagsString: String?
    @objc var tagsString: String? {
        get {
            return _tagsString
        }
        set(tags) {
            _tagsString = tags

            if (tagsString?.count ?? 0) <= 0 {
                tagsList.text = NSLocalizedString("none", comment: "none")
            } else {
                tagsList.text = tagsString
            }
        }
    }

    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()

        // Cell background
        backgroundColor = UIColor.piwigoColorBackground()

        // Cell label
        tagsLabel.text = NSLocalizedString("editImageDetails_tags", comment: "Tags")

        // Cell tags list
        tagsString = ""
    }

    @objc
    func setTagList(fromList tags: [PiwigoTagData]?, inColor color: UIColor?) {
        tagsString = TagsData.sharedInstance().getTagsString(fromList: tags)
        tagsLabel.textColor = UIColor.piwigoColorLeftLabel()
        tagsList.textColor = color
    }
}
