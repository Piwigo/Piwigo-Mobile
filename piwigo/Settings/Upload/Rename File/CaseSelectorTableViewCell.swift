//
//  CaseSelectorTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/04/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

typealias cellCaseSelectorBlock = () -> Void

class CaseSelectorTableViewCell: UITableViewCell {
    
    var cellCaseSelectorBlock: cellCaseSelectorBlock?

    @IBOutlet var segmentedControl: UISegmentedControl!
    
    func configure(with selectedSegmentIndex: Int) {
        
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        if #available(iOS 13.0, *) {
            segmentedControl.selectedSegmentTintColor = .piwigoColorOrange()
        } else {
            segmentedControl.tintColor = .piwigoColorOrange()
        }

        // Select proper segment
        self.segmentedControl.selectedSegmentIndex = selectedSegmentIndex
        self.segmentedControl.setEnabled(true, forSegmentAt: 0)
        self.segmentedControl.setTitle(NSLocalizedString("settings_renameLowercase", comment: "Lowercase"), forSegmentAt: FileExtCase.lowercase.rawValue)
        self.segmentedControl.setEnabled(true, forSegmentAt: 1)
        self.segmentedControl.setTitle(NSLocalizedString("settings_renameUppercase", comment: "Uppercase"), forSegmentAt: FileExtCase.uppercase.rawValue)
    }
    
    @IBAction func didValueChanged(_ sender: Any) {
        UploadVars.shared.caseOfFileExtension = segmentedControl.selectedSegmentIndex
        (cellCaseSelectorBlock ?? { return})()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
