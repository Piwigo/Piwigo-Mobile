//
//  ImageHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

protocol ImageHeaderDelegate: NSObjectProtocol {
    func changeImageGrouping(for group: pwgImageGroup)
}

class ImageHeaderReusableView: UICollectionReusableView
{
    weak var imageHeaderDelegate: ImageHeaderDelegate?

    private var dateLabelText: String = ""
    private var optionalDateLabelText: String = ""

    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    func config(with images: [Image], sortOption: pwgImageSort) {
        
        // General settings
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)
        
        // Date label used when place name known
        dateLabel.textColor = .piwigoColorRightLabel()
        
        // Place name of location
        placeLabel.textColor = .piwigoColorLeftLabel()

        // Get date labels from images in section
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
        
        dateLabel.text = ""
        placeLabel.text = ""
        selectButton.setTitle("", for: .normal)
        selectButton.backgroundColor = .piwigoColorBackground()
    }
}
