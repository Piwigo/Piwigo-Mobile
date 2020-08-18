//
//  SwitchTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 3/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 12/04/2020.
//

import UIKit

typealias CellSwitchBlock = (Bool) -> Void

class SwitchTableViewCell: UITableViewCell {

    @IBOutlet weak var switchName: UILabel!
    @IBOutlet weak var cellSwitch: UISwitch!

    var cellSwitchBlock: CellSwitchBlock?

    func configure(with title:String) {

        // Background color and aspect
        backgroundColor = UIColor.piwigoColorCellBackground()

        // Switch name
        switchName.font = UIFont.piwigoFontNormal()
        switchName.textColor = UIColor.piwigoColorLeftLabel()
        switchName.text = title
        switchName.preferredMaxLayoutWidth = 150

        // Switch appearance and action
        cellSwitch.thumbTintColor = UIColor.piwigoColorThumb()
        cellSwitch.onTintColor = UIColor.piwigoColorOrange()
    }

    @IBAction func switchChanged(_ sender: Any) {
        (cellSwitchBlock ?? {_ in return})(cellSwitch.isOn)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        switchName.text = ""
    }
}
