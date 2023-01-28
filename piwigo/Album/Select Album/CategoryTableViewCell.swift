//
//  CategoryTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

enum pwgCategoryCellButtonState : Int {
    case none
    case showSubAlbum
    case hideSubAlbum
}

@objc
protocol CategoryCellDelegate: NSObjectProtocol {
    func tappedDisclosure(of categoryTapped: Album)
}

class CategoryTableViewCell: UITableViewCell, CAAnimationDelegate {
    
    weak var delegate: CategoryCellDelegate?
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var subCategoriesLabel: UILabel!
    @IBOutlet weak var showHideSubCategoriesImage: UIImageView!
    @IBOutlet weak var showHideSubCategoriesGestureArea: UIView!
    
    private var albumData: Album!
    private var buttonState: pwgCategoryCellButtonState = .none
    
    func configure(with album: Album, atDepth depth:Int,
                   andButtonState buttonState:pwgCategoryCellButtonState) {
        // General settings
        backgroundColor = .piwigoColorCellBackground()
        tintColor = .piwigoColorOrange()

        // Category data
        albumData = album
        
        // Is this a sub-category?
        albumLabel.font = .systemFont(ofSize: 17)
        albumLabel.textColor = .piwigoColorLeftLabel()
        albumLabel.text = albumData.name
        if depth == 0 {
            // Categories in root album or root album itself
            leadingConstraint.constant = 20.0
        } else {
            // Shift sub-category names to the right
            leadingConstraint.constant = 20.0 + 12.0 * CGFloat(min(depth,4))
        }
        
        // Show open/close button (# sub-albums) if there are sub-categories
        if (albumData.nbSubAlbums <= 0) || buttonState == .none {
            subCategoriesLabel.text = ""
            showHideSubCategoriesImage.isHidden = true
        } else {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData.nbSubAlbums)) ?? "0"
            subCategoriesLabel.text = albumData.nbSubAlbums > 1 ?
                String(format: NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums"), nberAlbums) :
                String(format: NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album"), nberAlbums);
            
            self.buttonState = buttonState  // Remember button state
            showHideSubCategoriesImage.isHidden = false
            showHideSubCategoriesImage.tintColor = .piwigoColorOrange()  // required on iOS 9
            if #available(iOS 13.0, *) {
                showHideSubCategoriesImage.image = UIImage(systemName: "chevron.forward")
            } else {
                // Fallback on earlier versions
                showHideSubCategoriesImage.image = UIImage(named: "openClose")
            }
            if buttonState == .hideSubAlbum {
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
        let sign = buttonState == .showSubAlbum ? +1.0 : -1.0
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear) { [unowned self] in
            // Rotate the chevron
            self.showHideSubCategoriesImage.transform = self.showHideSubCategoriesImage.transform.rotated(by: CGFloat(sign * .pi/2.0))
            if self.buttonState == .hideSubAlbum {
                self.buttonState = .showSubAlbum
            } else {
                self.buttonState = .hideSubAlbum
            }
            
            // Add/remove sub-categories
            self.delegate?.tappedDisclosure(of: self.albumData)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        albumLabel.text = ""
    }
}
