//
//  UploadImageHeaderView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/08/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

class UploadImageHeaderView: UITableViewHeaderFooterView {
    
    var headerLabel = UILabel()
    var headerBckg: UIView!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerBckg = UIView(frame: self.bounds)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func config(with sectionKey: SectionKeys) {
        // Title
        let headerAttributedString = NSMutableAttributedString(string: "")
        let titleAttributedString = NSMutableAttributedString(string: sectionKey.name)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: sectionKey.name.count))
        headerAttributedString.append(titleAttributedString)

        // Header label
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.attributedText = headerAttributedString
        
        // Header background
        headerBckg.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)

        // Header view
        backgroundView = headerBckg
        addSubview(headerLabel)
        addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
                "header": headerLabel
            ]))
    }

//    func sectionNameFor(_ sectionKey: String) -> String {
//        var sectionName = "—?—"
//        let section = SectionKeys.init(rawValue: sectionKey)
//        switch section {
//        case .Section1:
//            sectionName = NSLocalizedString("uploadSection_impossible", comment: "Impossible Uploads")
//        case .Section2:
//            sectionName = NSLocalizedString("uploadSection_resumable", comment: "Resumable Uploads")
//        case .Section3:
//            sectionName = NSLocalizedString("uploadSection_queue", comment: "Uploads Queue")
//        case .Section4:
//            fallthrough
//        default:
//            sectionName = "—?—"
//        }
//        return sectionName
//    }
}
