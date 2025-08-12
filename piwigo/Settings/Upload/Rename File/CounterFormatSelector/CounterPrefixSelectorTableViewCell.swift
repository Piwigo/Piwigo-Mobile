//
//  CounterPrefixSelectorTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

typealias cellPrefixSelectorBlock = (pwgCounterFormat.Prefix) -> Void

class CounterPrefixSelectorTableViewCell: UITableViewCell {
    
    var cellPrefixSelectorBlock: cellPrefixSelectorBlock?

    @IBOutlet var segmentedControl: UISegmentedControl!
    
    func configure(with choice: String) {
        
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        segmentedControl.selectedSegmentTintColor = .piwigoColorOrange()

        // Configure segments
        let prefixes = pwgCounterFormat.Prefix.allCases.filter({$0 != .none})
        segmentedControl.removeAllSegments()
        for (index, prefix) in prefixes.enumerated() {
            self.segmentedControl.insertSegment(withTitle: prefix.rawValue, at: index, animated: false)
            self.segmentedControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17)], for: .normal)
            self.segmentedControl.setEnabled(true, forSegmentAt: index)
            if choice == prefix.rawValue {
                self.segmentedControl.selectedSegmentIndex = index
            }
        }
    }
    
    @IBAction func didValueChanged(_ sender: Any) {
        let index = self.segmentedControl.selectedSegmentIndex
        let title = self.segmentedControl.titleForSegment(at: index) ?? ""
        let choice = pwgCounterFormat.Prefix.init(rawValue: title) ?? .none
        (cellPrefixSelectorBlock ?? {_ in return})(choice)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
