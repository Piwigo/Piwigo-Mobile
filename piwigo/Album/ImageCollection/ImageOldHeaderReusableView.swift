//
//  ImageOldHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class ImageOldHeaderReusableView: UICollectionReusableView
{
    var section = 0
    private var locationHash = Int.zero
    
    weak var imageHeaderDelegate: ImageHeaderDelegate?

    private var dateLabelText: String = ""
    private var optionalDateLabelText: String = ""

    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var albumLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var mainLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    func config(with images: [Image], sortKey: String, group: pwgImageGroup,
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
        
        // Segmented controller
        segmentedControl?.selectedSegmentIndex = group.segmentIndex

        // Get date labels
        var dates = ("", "")
        switch sortKey {
        case #keyPath(Image.dateCreated):
            let dateIntervals = images.map {$0.dateCreated}
            dates = AlbumUtilities.getDateLabels(for: dateIntervals, arePwgDates: true)
        case #keyPath(Image.datePosted):
            let dateIntervals = images.map {$0.datePosted}
            dates = AlbumUtilities.getDateLabels(for: dateIntervals, arePwgDates: true)
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
    
    @MainActor
    func applyColorPalette() {
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)
        mainLabel.textColor = .piwigoColorLeftLabel()
        detailLabel.textColor = .piwigoColorRightLabel()
        if #available(iOS 13.0, *) {
            segmentedControl?.selectedSegmentTintColor = .piwigoColorOrange()
        } else {
            segmentedControl?.tintColor = .piwigoColorOrange()
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

    @IBAction func tappedSelectButton(_ sender: Any) {
        // Select/deselect images
        imageHeaderDelegate?.didSelectImagesOfSection(section)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        mainLabel.text = ""
        detailLabel.text = ""
        selectButton.setTitle("", for: .normal)
        selectButton.backgroundColor = .piwigoColorBackground()
    }

    @IBAction func didChangeGroupType(_ sender: Any) {
        switch segmentedControl?.selectedSegmentIndex {
        case 0:     /* Photos grouped by month */
            let isActive = AlbumVars.shared.defaultGroup == .month
            if isActive { return }
            imageHeaderDelegate?.changeImageGrouping(for: .month)
        
        case 1:     /* Photos grouped by week */
            let isActive = AlbumVars.shared.defaultGroup == .week
            if isActive { return }
            imageHeaderDelegate?.changeImageGrouping(for: .week)
        
        case 2:     /* Photos grouped by day */
            let isActive = AlbumVars.shared.defaultGroup == .day
            if isActive { return }
            imageHeaderDelegate?.changeImageGrouping(for: .day)
            
        case 3:     /* Photos not grouped by day, week or maointh */
            let isActive = AlbumVars.shared.defaultGroup == .none
            if isActive { return }
            imageHeaderDelegate?.changeImageGrouping(for: .none)
            
        default:
            break
        }
    }
}
