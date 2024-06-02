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
}

class ImageHeaderReusableView: UICollectionReusableView
{
    var locationHash = Int.zero
    
    weak var imageHeaderDelegate: ImageHeaderDelegate?

    @IBOutlet weak var mainLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    func config(with images: [Image], sortOption: pwgImageSort) {
        
        // General settings
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)
        
        // Date & place name labels
        mainLabel.textColor = .piwigoColorLeftLabel()
        detailLabel.textColor = .piwigoColorRightLabel()

        // Get date labels from images in section
        var date1: Date?, date2: Date?, dates = ("", "")
        switch sortOption {
        case .dateCreatedAscending, .dateCreatedDescending:
            if let ti = images.first?.dateCreated {
                date1 = Date(timeIntervalSinceReferenceDate: ti)
            }
            if let ti = images.last?.dateCreated {
                date2 = Date(timeIntervalSinceReferenceDate: ti)
            }
            dates = AlbumUtilities.getDateLabels(for: date1, to: date2)

        case .datePostedAscending, .datePostedDescending:
            if let ti = images.first?.datePosted {
                date1 = Date(timeIntervalSinceReferenceDate: ti)
            }
            if let ti = images.last?.datePosted {
                date2 = Date(timeIntervalSinceReferenceDate: ti)
            }
            dates = AlbumUtilities.getDateLabels(for: date1, to: date2)
        default:
            break
        }

        // Set labels from dates and place name
        self.mainLabel.text = dates.0
        if images.isEmpty {
            self.detailLabel.text = dates.1
        } else {
            // Determine location from images in section
            let location = AlbumUtilities.getLocation(of: images)
            LocationProvider.shared.getPlaceName(for: location) { [unowned self] placeName, streetName in
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

    override func prepareForReuse() {
        super.prepareForReuse()
        
        mainLabel.text = ""
        detailLabel.text = ""
        selectButton.setTitle("", for: .normal)
        selectButton.backgroundColor = .piwigoColorBackground()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
