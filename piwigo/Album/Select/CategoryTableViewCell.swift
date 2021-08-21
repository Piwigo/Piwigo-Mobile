//
//  CategoryTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

//enum kPiwigoCategoryTableCellButtonState : Int {
//    case none
//    case showSubAlbum
//    case hideSubAlbum
//}

@objc
protocol CategoryCellDelegate: NSObjectProtocol {
    func tappedDisclosure(of categoryTapped: PiwigoAlbumData)
}

class CategoryTableViewCell: UITableViewCell, CAAnimationDelegate {
    
    @objc weak var delegate: CategoryCellDelegate?
    
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var subCategoriesLabel: UILabel!
    @IBOutlet weak var showHideSubCategoriesImage: UIImageView!
    @IBOutlet weak var showHideSubCategoriesGestureArea: UIView!
    
    private var categoryData:PiwigoAlbumData!
    private var buttonState = kPiwigoCategoryTableCellButtonStateNone
    
    @objc func configure(with category:PiwigoAlbumData, atDepth depth:Int,
                         andButtonState buttonState:kPiwigoCategoryTableCellButtonState) {
        // General settings
        backgroundColor = UIColor.piwigoColorCellBackground()
        tintColor = UIColor.piwigoColorOrange()

        // Category data
        categoryData = category
        
        // Is this a sub-category?
        categoryLabel.font = UIFont.piwigoFontNormal()
        categoryLabel.textColor = UIColor.piwigoColorLeftLabel()
        if depth == 0 {
            // Categories in root album or root album itself
            categoryLabel.text = categoryData.name
        } else {
            // Append "—" characters to sub-category names
            let subAlbumPrefix = "".padding(toLength: depth, withPad: "…", startingAt: 0)
            if AppVars.isAppLanguageRTL {
                categoryLabel.text = String(format: "%@ %@", categoryData.name, subAlbumPrefix)
            } else {
                categoryLabel.text = String(format: "%@ %@", subAlbumPrefix, categoryData.name)
            }
        }
        
        // Show open/close button (# sub-albums) if there are sub-categories
        if (category.numberOfSubCategories <= 0) || buttonState == kPiwigoCategoryTableCellButtonStateNone {
            subCategoriesLabel.text = ""
            showHideSubCategoriesImage.isHidden = true
        } else {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let nberAlbums = numberFormatter.string(from: NSNumber(value: categoryData.numberOfSubCategories)) ?? "0"
            subCategoriesLabel.text = categoryData.numberOfSubCategories > 1 ?
                String(format: NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums"), nberAlbums) :
                String(format: NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album"), nberAlbums);
            
            self.buttonState = buttonState  // Remember button state
            showHideSubCategoriesImage.isHidden = false
            showHideSubCategoriesImage.tintColor = UIColor.piwigoColorOrange()  // required on iOS 9
            if #available(iOS 13.0, *) {
                showHideSubCategoriesImage.image = UIImage(systemName: "chevron.forward")
            } else {
                // Fallback on earlier versions
                showHideSubCategoriesImage.image = UIImage(named: "openClose")
            }
            if buttonState == kPiwigoCategoryTableCellButtonStateHideSubAlbum {
                self.showHideSubCategoriesImage.transform = CGAffineTransform(rotationAngle: CGFloat(.pi/2.0))
            } else {
                self.showHideSubCategoriesImage.transform = CGAffineTransform.identity
            }

            // Execute tappedLoadView whenever tapped
            showHideSubCategoriesGestureArea.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tappedLoadView)))
        }
    }
    
    @objc func tappedLoadView() {
        // Rotate icon
        let sign = buttonState == kPiwigoCategoryTableCellButtonStateShowSubAlbum ? +1.0 : -1.0
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear) {
            self.showHideSubCategoriesImage.transform = self.showHideSubCategoriesImage.transform.rotated(by: CGFloat(sign * .pi/2.0))
            self.layoutIfNeeded()
        } completion: { [unowned self] _ in
            // Add/remove sub-categories
            self.delegate?.tappedDisclosure(of: self.categoryData)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        categoryLabel.text = ""
    }
}
