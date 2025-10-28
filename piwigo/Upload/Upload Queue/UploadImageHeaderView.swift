//
//  UploadImageHeaderView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class UploadImageHeaderView: UITableViewHeaderFooterView {
    
    var headerLabel = UILabel()
    var headerBckg: UIView!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        headerBckg = UIView(frame: self.bounds)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func config(with sectionKey: SectionKeys) {
        // Header label
        headerLabel.textColor = PwgColor.header
        headerLabel.text = sectionKey.name
        
        // Header background
        headerBckg.backgroundColor = PwgColor.background.withAlphaComponent(0.75)

        // Header view
        backgroundView = headerBckg
        addSubview(headerLabel)
        addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
                "header": headerLabel
            ]))
    }
}
