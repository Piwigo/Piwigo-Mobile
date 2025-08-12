//
//  DateSeparatorSelectorTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/04/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

typealias cellSeparatorSelectorBlock = (pwgSeparator) -> Void

class SeparatorSelectorTableViewCell: UITableViewCell {
    
    var cellSeparatorSelectorBlock: cellSeparatorSelectorBlock?

    @IBOutlet var segmentedControl: UISegmentedControl!
    
    func configure(with choice: String) {
        
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        segmentedControl.selectedSegmentTintColor = .piwigoColorOrange()

        // Configure segments
        let separators = pwgSeparator.allCases.filter({$0 != .none})
        segmentedControl.removeAllSegments()
        for (index, separator) in separators.enumerated() {
            let character = separator.rawValue == " " ? "␣" : separator.rawValue
            self.segmentedControl.insertSegment(withTitle: character, at: index, animated: false)
            self.segmentedControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17)], for: .normal)
            self.segmentedControl.setEnabled(true, forSegmentAt: index)
            if choice == separator.rawValue {
                self.segmentedControl.selectedSegmentIndex = index
            }
        }
    }
    
    @IBAction func didValueChanged(_ sender: Any) {
        let index = self.segmentedControl.selectedSegmentIndex
        let title = self.segmentedControl.titleForSegment(at: index) ?? ""
        let character = title == "␣" ? " " : title
        let choice = pwgSeparator.init(rawValue: character) ?? .dash
        (cellSeparatorSelectorBlock ?? {_ in return})(choice)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
