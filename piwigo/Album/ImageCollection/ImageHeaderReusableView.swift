//
//  ImageHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit
import piwigoKit

protocol ImageHeaderDelegate: NSObjectProtocol {
    func changeImageGrouping(for group: pwgImageGroup)
    func didSelectImagesOfSection(_ section: Int)
}

class ImageHeaderReusableView: UICollectionReusableView
{
    var section = 0
    private var locationHash = Int.zero
    
    weak var imageHeaderDelegate: ImageHeaderDelegate?

    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var albumLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var mainLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    func config(with images: [Image], sortKey: String,
                section: Int, selectState: SelectButtonState,
                album description: NSAttributedString = NSAttributedString(), size: CGSize = CGSize.zero)
    {
        // Keep section for future use
        self.section = section
        
        // Set colors
        applyColorPalette()

        // Set album description label
        if size == CGSize.zero {
            albumLabel.text = ""
            albumLabelHeight.constant = 0
        } else {
            albumLabel.attributedText = description
            albumLabelHeight.constant = size.height
        }
        
        // Get date labels from images in section
        var dates = ("", "")
        switch sortKey {
        case #keyPath(Image.dateCreated):
            let dateIntervals = images.map {$0.dateCreated}
            dates = AlbumUtilities.getDateLabels(for: dateIntervals, arePwgDates: true)
        case #keyPath(Image.datePosted):
            let dateIntervals = images.map {$0.datePosted}
            dates = AlbumUtilities.getDateLabels(for: dateIntervals, arePwgDates: true)
        default:
            dates = (" ", " ")
            break
        }
        
        // Set labels from dates and place name
        self.mainLabel.text = dates.0
        if images.isEmpty {
            self.detailLabel.text = dates.1
        } else {
            // Determine location from images in section
            let location = AlbumUtilities.getLocation(of: images)
            LocationProvider.shared.getPlaceName(for: location) { [self] placeName, streetName in
                if placeName.isEmpty {
                    self.detailLabel.text = dates.1
                } else if streetName.isEmpty {
                    self.detailLabel.text = placeName
                } else {
                    self.detailLabel.text = String(format: "%@ • %@", placeName, streetName)
                }
            } pending: { hash in
                // Show date details until place name availability
                self.detailLabel.text = dates.1
                // Register location provider
                self.locationHash = hash
                NotificationCenter.default.addObserver(self, selector: #selector(self.updateDetailLabel(_:)),
                                                       name: Notification.Name.pwgPlaceNamesAvailable, object: nil)
            } failure: {
                self.detailLabel.text = dates.1
            }
        }

        // Select/deselect button
        selectButton.layer.cornerRadius = 13.0
        selectButton.setTitle(forState: selectState)
    }
    
    func applyColorPalette() {
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)
        mainLabel.textColor = .piwigoColorLeftLabel()
        detailLabel.textColor = .piwigoColorRightLabel()
        selectButton.backgroundColor = .piwigoColorBackground()
        albumLabel.textColor = .piwigoColorHeader()
    }
    
    @objc func updateDetailLabel(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let hash = info["hash"] as? Int, hash == locationHash,
              let placeName = info["placeName"] as? String,
              let streetName = info["streetName"] as? String
        else { return }
        
        // Update detail label
        if streetName.isEmpty {
            self.detailLabel.text = placeName
        } else {
            self.detailLabel.text = String(format: "%@ • %@", placeName, streetName)
        }
        NotificationCenter.default.removeObserver(self, name: Notification.Name.pwgPlaceNamesAvailable, object: nil)
    }

    @IBAction func tappedSelectButton(_ sender: Any) {
        // Select/deselect images
        imageHeaderDelegate?.didSelectImagesOfSection(section)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        mainLabel.text = ""
        detailLabel.text = ""
        selectButton.setTitle("", for: .normal)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
