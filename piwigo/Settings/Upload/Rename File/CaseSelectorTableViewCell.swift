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

typealias cellCaseSelectorBlock = (FileExtCase) -> Void

class CaseSelectorTableViewCell: UITableViewCell {
    
    var cellCaseSelectorBlock: cellCaseSelectorBlock?

    @IBOutlet var segmentedControl: UISegmentedControl!
    
    func configure(with caseType: FileExtCase) {
        
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        segmentedControl.selectedSegmentTintColor = .piwigoColorOrange()

        // Select proper segment
        let selectedSegmentIndex: Int = caseType == .keep ? 1 : Int(UploadVars.shared.caseOfFileExtension)
        self.segmentedControl.selectedSegmentIndex = selectedSegmentIndex
        self.segmentedControl.setEnabled(true, forSegmentAt: 0)
        self.segmentedControl.setTitle(NSLocalizedString("settings_renameLowercase", comment: "Lowercase"), forSegmentAt: 0)
        self.segmentedControl.setEnabled(true, forSegmentAt: 1)
        self.segmentedControl.setTitle(NSLocalizedString("settings_renameUppercase", comment: "Uppercase"), forSegmentAt: 1)
    }
    
    @IBAction func didValueChanged(_ sender: Any) {
        // The raw value is stored in the Core Data persistent store.
        // A zero value is adopted in the persistent store when the case should not be changed.
        let caseOfFileExtension = FileExtCase(rawValue: Int16(segmentedControl.selectedSegmentIndex)) ?? .keep
        (cellCaseSelectorBlock ?? {_ in return})(caseOfFileExtension)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
