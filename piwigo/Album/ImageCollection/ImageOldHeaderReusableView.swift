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
    weak var imageHeaderDelegate: ImageHeaderDelegate?

    private var dateLabelText: String = ""
    private var optionalDateLabelText: String = ""

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    func config(with images: [Image], sortOption: pwgImageSort, group: pwgImageGroup) {
        // Segmented controller
        if #available(iOS 13.0, *) {
            segmentedControl?.selectedSegmentTintColor = .piwigoColorOrange()
        } else {
            segmentedControl?.tintColor = .piwigoColorOrange()
        }
        segmentedControl?.selectedSegmentIndex = group.segmentIndex

        // Date label used when place name known
        dateLabel.textColor = .piwigoColorRightLabel()

        // Place name of location
        placeLabel.textColor = .piwigoColorLeftLabel()

        // Get date labels
        var date1: Date?, date2: Date?
        switch sortOption {
        case .dateCreatedAscending, .dateCreatedDescending:
            if let ti = images.first?.dateCreated {
                date1 = Date(timeIntervalSinceReferenceDate: ti)
            }
            if let ti = images.last?.dateCreated {
                date2 = Date(timeIntervalSinceReferenceDate: ti)
            }
            (dateLabelText, optionalDateLabelText) = AlbumUtilities.getDateLabels(for: date1, to: date2)

        case .datePostedAscending, .datePostedDescending:
            if let ti = images.first?.datePosted {
                date1 = Date(timeIntervalSinceReferenceDate: ti)
            }
            if let ti = images.last?.datePosted {
                date2 = Date(timeIntervalSinceReferenceDate: ti)
            }
            (dateLabelText, optionalDateLabelText) = AlbumUtilities.getDateLabels(for: date1, to: date2)
        default:
            break
        }
        placeLabel.text = dateLabelText
        dateLabel.text = optionalDateLabelText
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
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
