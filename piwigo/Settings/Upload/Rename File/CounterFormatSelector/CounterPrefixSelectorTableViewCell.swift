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
    @IBOutlet weak var segmentedControlHeight: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var bottomMargin: NSLayoutConstraint!

    func configure(with choice: String) {
        
        // Background color and aspect
        backgroundColor = PwgColor.cellBackground
        topMargin.constant = TableViewUtilities.vertMargin
        bottomMargin.constant = TableViewUtilities.vertMargin
        segmentedControl.selectedSegmentTintColor = PwgColor.orange
        segmentedControl.setTitleTextAttributes(
            [.font : UIFont.preferredFont(forTextStyle: .body),
             .foregroundColor: PwgColor.gray
        ], for: .normal)
        segmentedControl.setTitleTextAttributes(
            [.font : UIFont.preferredFont(forTextStyle: .body),
             .foregroundColor: UIColor.white
        ], for: .selected)
        segmentedControlHeight.constant = UIFont.preferredFont(forTextStyle: .body).lineHeight +  TableViewUtilities.vertMargin

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
