//
//  CounterSuffixSelectorTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

typealias cellSuffixSelectorBlock = (pwgCounterFormat.Suffix) -> Void

class CounterSuffixSelectorTableViewCell: UITableViewCell {
    
    var cellSuffixSelectorBlock: cellSuffixSelectorBlock?

    @IBOutlet var segmentedControl: UISegmentedControl!
    
    func configure(with choice: String) {
        
        // Background color and aspect
        backgroundColor = .piwigoColorCellBackground()
        if #available(iOS 13.0, *) {
            segmentedControl.selectedSegmentTintColor = .piwigoColorOrange()
        } else {
            segmentedControl.tintColor = .piwigoColorOrange()
        }

        // Configure segments
        let suffixes = pwgCounterFormat.Suffix.allCases.filter({$0 != .none})
        segmentedControl.removeAllSegments()
        for (index, suffix) in suffixes.enumerated() {
            self.segmentedControl.insertSegment(withTitle: suffix.rawValue, at: index, animated: false)
            self.segmentedControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17)], for: .normal)
            self.segmentedControl.setEnabled(true, forSegmentAt: index)
            if choice == suffix.rawValue {
                self.segmentedControl.selectedSegmentIndex = index
            }
        }
    }
    
    @IBAction func didValueChanged(_ sender: Any) {
        let index = self.segmentedControl.selectedSegmentIndex
        let title = self.segmentedControl.titleForSegment(at: index) ?? ""
        let choice = pwgCounterFormat.Suffix.init(rawValue: title) ?? .none
        (cellSuffixSelectorBlock ?? {_ in return})(choice)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
