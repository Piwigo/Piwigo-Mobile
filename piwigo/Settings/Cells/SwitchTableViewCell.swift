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
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var bottomMargin: NSLayoutConstraint!

    var cellSwitchBlock: CellSwitchBlock?

    func configure(with title:String) {

        // Background color and aspect
        backgroundColor = PwgColor.cellBackground
        topMargin.constant = TableViewUtilities.vertMargin
        bottomMargin.constant = TableViewUtilities.vertMargin

        // Switch name
        switchName.textColor = PwgColor.leftLabel
        switchName.text = title

        // Switch appearance and action
        cellSwitch.thumbTintColor = PwgColor.thumb
        cellSwitch.onTintColor = PwgColor.orange
    }

    @IBAction func switchChanged(_ sender: Any) {
        (cellSwitchBlock ?? {_ in return})(cellSwitch.isOn)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        switchName.text = ""
    }
}
