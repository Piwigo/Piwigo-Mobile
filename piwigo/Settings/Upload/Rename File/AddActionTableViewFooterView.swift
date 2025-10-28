//
//  AddActionTableViewFooterView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

class AddActionTableViewFooterView: UITableViewHeaderFooterView {
    
    let button = UIButton()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        config()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func config() {
        // Create Add Action button
        button.setTitle(NSLocalizedString("alertAddButton", comment: "Add"), for: .normal)
        button.setTitleColor(PwgColor.orange, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Create footer view
        contentView.backgroundColor = .clear
        contentView.addSubview(button)
        NSLayoutConstraint.activate(NSLayoutConstraint.constraintCenter(button)!)
    }
    
    func setEnabled(_ enabled: Bool) {
        button.isEnabled = enabled
        button.alpha = enabled ? 1 : 0
    }
}
