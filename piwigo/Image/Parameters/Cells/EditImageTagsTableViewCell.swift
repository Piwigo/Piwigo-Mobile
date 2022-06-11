//
//  EditImageTagsTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 29/08/2021.
//

import UIKit

class EditImageTagsTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var tagsLabel: UILabel!
    @IBOutlet private weak var tagsList: UILabel!

    private var _tagsString: String?
    var tagsString: String? {
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
        backgroundColor = .piwigoColorBackground()

        // Cell label
        tagsLabel.text = NSLocalizedString("editImageDetails_tags", comment: "Tags")

        // Cell tags list
        tagsString = ""
    }

    func config(withList tags: [PiwigoTagData]?, inColor color: UIColor?) {
        // Set colours
        tagsLabel.textColor = .piwigoColorLeftLabel()
        tagsList.textColor = color

        // Check tag data
        tagsString = ""
        guard let tags = tags else { return }

        // Compile list of tags
        tagsString = String(tags.compactMap({"\($0.tagName ?? "?"), "}).reduce("", +).dropLast(2))
    }
}
