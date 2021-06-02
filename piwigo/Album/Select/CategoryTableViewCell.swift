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

class CategoryTableViewCell: UITableViewCell {
    
    @objc weak var delegate: CategoryCellDelegate?
    
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var subCategoriesLabel: UILabel!
    @IBOutlet weak var showHideSubCategoriesImage: UIImageView!
    @IBOutlet weak var showHideSubCategoriesGestureArea: UIView!
    
    private var categoryData:PiwigoAlbumData!
    
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
            if AppVars.shared.isAppLanguageRTL {
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
            subCategoriesLabel.text = String(format: "%ld %@",
                                   categoryData.numberOfSubCategories,
                                   categoryData.numberOfSubCategories > 1 ? NSLocalizedString("categoryTableView_subCategoriesCount", comment:"sub-albums") : NSLocalizedString("categoryTableView_subCategoryCount", comment:"sub-album"))
            
            if buttonState == kPiwigoCategoryTableCellButtonStateShowSubAlbum {
                if #available(iOS 13.0, *) {
                    showHideSubCategoriesImage.image = UIImage(systemName: "plus")
                } else {
                    // Fallback on earlier versions
                    showHideSubCategoriesImage.image = UIImage(named: "cellOpen")
                }
            } else {
                if #available(iOS 13.0, *) {
                    showHideSubCategoriesImage.image = UIImage(systemName: "multiply")
                } else {
                    // Fallback on earlier versions
                    showHideSubCategoriesImage.image = UIImage(named: "cellClose")
                }
            }
            showHideSubCategoriesImage.tintColor = UIColor.piwigoColorOrange()  // required on iOS 9
            showHideSubCategoriesImage.isHidden = false
        }

        // Execute tappedLoadView whenever tapped
        showHideSubCategoriesGestureArea.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tappedLoadView)))
    }
    
    @objc func tappedLoadView() {
        delegate?.tappedDisclosure(of: categoryData)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        categoryLabel.text = ""
    }
}
