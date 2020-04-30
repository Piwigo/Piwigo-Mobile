//
//  LocalImagesHeaderReusableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 13/04/2020
//

import Photos
import UIKit

@objc protocol LocalImagesHeaderDelegate: NSObjectProtocol {
    func didSelectImagesOfSection(_ section: Int)
}

@objc
class LocalImagesHeaderReusableView: UICollectionReusableView {
    
    @objc weak var headerDelegate: LocalImagesHeaderDelegate?
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var placeLabel: UILabel!

    @objc
    func configure(with images: [[PHAsset]], section: Int, placeNames: [AnyHashable : Any]?, selectionMode: Bool) {
        
        // General settings
        backgroundColor = UIColor.clear

        // Keep section for future use
        self.section = section

        // Creation date of images (or of availability)
        var imageAsset = images[section].first
        var dateLabelText = ""
        var optionalDateLabelText = ""

        // Determine if images of this section were all taken today
        if let dateCreated1 = imageAsset?.creationDate {
            
            // Display date of day by default, will add time in the absence of location data
            dateLabelText = DateFormatter.localizedString(from: dateCreated1, dateStyle: .long, timeStyle: .none)
            optionalDateLabelText = DateFormatter.localizedString(from: dateCreated1, dateStyle: .none, timeStyle: .long)
            
            // Get creation date of last image
            imageAsset = images[section].last
            if let dateCreated2 = imageAsset?.creationDate {
                
                // Set dates in right order in case user sorted images in reverse order
                let firstImageDate = (dateCreated1 < dateCreated2) ? dateCreated1 : dateCreated2
                let lastImageDate = (dateCreated1 > dateCreated2) ? dateCreated1 : dateCreated2
                let firstImageDay: Date = Calendar.current.startOfDay(for: firstImageDate)          // Day the first image was taken in seconds
                let lastImageDay: Date = Calendar.current.startOfDay(for: lastImageDate)            // Day the last image was taken in seconds

                // Images taken the same day?
                if firstImageDay == lastImageDay {
                    // Images were taken the same day => Keep dataLabel as already set and define optional string with starting and ending times
                    let firstImageDateStr = DateFormatter.localizedString(from: firstImageDate, dateStyle: .none, timeStyle: .short)
                    let lastImageDateStr = DateFormatter.localizedString(from: lastImageDate, dateStyle: .none, timeStyle: .short)
                    if (firstImageDateStr == lastImageDateStr) {
                        optionalDateLabelText = firstImageDateStr
                    } else {
                        optionalDateLabelText = "\(firstImageDateStr) - \(lastImageDateStr)"
                    }
                } else {
                    // => Images not taken the same day => Will display the starting and ending dates
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.locale = .current
                    if UIScreen.main.bounds.size.width > 414 {
                        // i.e. larger than iPhones 6, 7 screen width
                        dateFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
                        dateLabelText = dateFormatter.string(from: dateCreated1) + " - " + dateFormatter.string(from: dateCreated2)
                    } else {
                        dateFormatter.setLocalizedDateFormatFromTemplate("MMd")
                        dateLabelText = dateFormatter.string(from: dateCreated1) + " - " + dateFormatter.string(from: dateCreated2)
                    }
                    // Define optional string with starting and ending year
                    dateFormatter.setLocalizedDateFormatFromTemplate("YYYY")
                    let firstYear = dateFormatter.string(from: dateCreated1)
                    let lastYear = dateFormatter.string(from: dateCreated2)
                    if firstYear == lastYear {
                        optionalDateLabelText = firstYear
                    } else {
                        optionalDateLabelText = firstYear + " - " + lastYear
                    }
                }
            }
        }

        // Data label used when place name known
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.numberOfLines = 1
        dateLabel.adjustsFontSizeToFitWidth = false
        dateLabel.font = UIFont.piwigoFontSmall()
        dateLabel.textColor = UIColor.piwigoColorRightLabel()

        // Place name of location
        placeLabel.translatesAutoresizingMaskIntoConstraints = false
        placeLabel.numberOfLines = 1
        placeLabel.adjustsFontSizeToFitWidth = false
        placeLabel.font = UIFont.piwigoFontSemiBold()
        placeLabel.textColor = UIColor.piwigoColorLeftLabel()

        // Use label according to name availabilities
        if let placeLabelName = placeNames?["placeLabel"] as? String {
            placeLabel.text = placeLabelName
            if let dateLabelName = placeNames?["dateLabel"] as? String {
                self.dateLabel.text = String(format: "%@ • %@", dateLabelText, dateLabelName)
            } else {
                self.dateLabel.text = String(format: "%@ • %@", dateLabelText, optionalDateLabelText)
            }
        } else {
            placeLabel.text = dateLabelText
            dateLabel.text = optionalDateLabelText
        }

        // Select/deselect button
        tintColor = UIColor.piwigoColorOrange()
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorOrange(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        let title = selectionMode ? NSLocalizedString("categoryImageList_deselectButton", comment: "Deselect") : NSLocalizedString("categoryImageList_selectButton", comment: "Select")
        let buttonTitle = NSAttributedString(string: title, attributes: attributes)
        selectButton.setAttributedTitle(buttonTitle, for: .normal)
    }

    private var section = 0

    @IBAction func tappedSelectButton(_ sender: Any) {
        if headerDelegate?.responds(to: #selector(LocalImagesHeaderDelegate.didSelectImagesOfSection(_:))) ?? false {
            // Select/deselect section of images
            headerDelegate?.didSelectImagesOfSection(section)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        dateLabel.text = ""
        placeLabel.text = ""
    }
}
