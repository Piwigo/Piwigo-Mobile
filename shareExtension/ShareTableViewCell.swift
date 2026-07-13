//
//  ShareTableViewCell.swift
//  shareExtension
//
//  Created by Eddy Lelièvre-Berna on 02/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

enum pwgShareCellButtonState : Int {
    case none
    case showSubAlbum
    case hideSubAlbum
}

protocol ShareCellDelegate: NSObjectProtocol {
    func tappedDisclosure(of categoryTapped: Album)
}

final class ShareTableViewCell: UITableViewCell, CAAnimationDelegate {
    
    weak var delegate: (any ShareCellDelegate)?
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var subCategoriesLabel: UILabel!
    @IBOutlet weak var showHideSubCategoriesImage: UIImageView!
    @IBOutlet weak var showHideSubCategoriesGestureArea: UIView!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var bottomMargin: NSLayoutConstraint!

    private var albumData: Album!
    private var buttonState: pwgShareCellButtonState = .none

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // awakeFromNib() of view objects is always called on the main thread
        MainActor.assumeIsolated {
            // Execute tappedLoadView whenever the disclosure area is tapped
            showHideSubCategoriesGestureArea.addGestureRecognizer(
                UITapGestureRecognizer(target: self, action: #selector(tappedLoadView)))
        }
    }
    
    func configure(with album: Album, atDepth depth:Int,
                   andButtonState buttonState:pwgShareCellButtonState) {
        // General settings
        backgroundColor = PwgColor.cellBackground
        tintColor = PwgColor.tintColor
        topMargin.constant = TableViewUtilities.vertMargin
        bottomMargin.constant = TableViewUtilities.vertMargin
        
        // Category data
        albumData = album
        
        // Is this a sub-category?
        albumLabel.textColor = PwgColor.leftLabel
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
            self.buttonState = .none
            subCategoriesLabel.text = ""
            showHideSubCategoriesImage.isHidden = true
        }
        else {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData.nbSubAlbums)) ?? "0"
            if traitCollection.preferredContentSizeCategory < .extraLarge {
                subCategoriesLabel.text = unsafe albumData.nbSubAlbums > 1
                    ? String(format: Localized.severalSubAlbumsCount, nberAlbums)
                    : String(format: Localized.singleSubAlbumCount, nberAlbums)
            } else {
                subCategoriesLabel.text = nberAlbums
            }
            
            self.buttonState = buttonState  // Remember button state
            showHideSubCategoriesImage.isHidden = false
            showHideSubCategoriesImage.tintColor = PwgColor.orange
            showHideSubCategoriesImage.image = UIImage(systemName: "chevron.forward")
            if buttonState == .hideSubAlbum {
                self.showHideSubCategoriesImage.transform = CGAffineTransform(rotationAngle: CGFloat(.pi/2.0))
            } else {
                self.showHideSubCategoriesImage.transform = CGAffineTransform.identity
            }
        }
    }
    
    @objc func tappedLoadView() {
        // Ignore taps when the open/close button is not presented
        if buttonState == .none { return }

        // Remember the new button state
        let sign = buttonState == .showSubAlbum ? +1.0 : -1.0
        buttonState = buttonState == .showSubAlbum ? .hideSubAlbum : .showSubAlbum
        
        // Rotate the chevron before adding/removing sub-categories
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveLinear) { [self] in
            // Rotate the chevron
            self.showHideSubCategoriesImage.transform = self.showHideSubCategoriesImage.transform.rotated(by: CGFloat(sign * .pi/2.0))
        }
        completion: { [self] _ in
            // Add/remove sub-categories
            self.delegate?.tappedDisclosure(of: self.albumData)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        albumLabel.text = ""
    }
}
