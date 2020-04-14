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
    @IBOutlet weak var dateLabelNoPlace: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var placeLabel: UILabel!

    @objc
    func configure(with images: [AnyHashable]?, placeNames: [AnyHashable : Any]?, in section: Int, selectionMode: Bool) {
        // General settings
        backgroundColor = UIColor.clear

        // Keep section for future use
        self.section = section

        // Creation date of images (or of availability)
        var imageAsset = images?.first as? PHAsset
        var dateLabelText = ""
        if let dateCreated1 = imageAsset?.creationDate {
            // Determine if images of this section were taken today

            // Display date of day by default
            dateLabelText = DateFormatter.localizedString(from: dateCreated1, dateStyle: .long, timeStyle: .none)
            
            // Define start time of today
            let start: Date = Calendar.current.startOfDay(for: Date())

            // Set day start time
            let dayStartInSecs = start.timeIntervalSinceReferenceDate

            // Get creation date of last image
            imageAsset = images?.last as? PHAsset
            if let dateCreated2 = imageAsset?.creationDate {
                // Set dates in right order
                let firstImageDate = (dateCreated1 < dateCreated2) ? dateCreated1 : dateCreated2
                let lastImageDate = (dateCreated1 > dateCreated2) ? dateCreated1 : dateCreated2
                let dateInSecs = firstImageDate.timeIntervalSinceReferenceDate

                // Images taken today?
                if dateInSecs > dayStartInSecs {
                    // Images taken today
                    var firstImageDateStr: String? = nil
                    firstImageDateStr = DateFormatter.localizedString(from: firstImageDate, dateStyle: DateFormatter.Style.none, timeStyle: .short)
                    var lastImageDateStr: String? = nil
                    lastImageDateStr = DateFormatter.localizedString(from: lastImageDate, dateStyle: DateFormatter.Style.none, timeStyle: .short)
                    if (firstImageDateStr == lastImageDateStr) {
                        dateLabelText = firstImageDateStr ?? ""
                    } else {
                        dateLabelText = "\(firstImageDateStr ?? "") - \(lastImageDateStr ?? "")"
                    }
                } else {
                    // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                    if UIScreen.main.bounds.size.width > 414 {
                        // i.e. larger than iPhones 6, 7 screen width
                        dateLabelText = DateFormatter.localizedString(from: dateCreated1, dateStyle: .long, timeStyle: .none)
                    } else {
                        dateLabelText = DateFormatter.localizedString(from: dateCreated1, dateStyle: .medium, timeStyle: .none)
                    }
                }
            }
        }

        // Data label used when place name known
        self.dateLabel.translatesAutoresizingMaskIntoConstraints = false
        self.dateLabel.numberOfLines = 1
        self.dateLabel.adjustsFontSizeToFitWidth = false
        self.dateLabel.font = UIFont.piwigoFontSmall()
        self.dateLabel.textColor = UIColor.piwigoColorRightLabel()

        // Data label used when place name unknown
        dateLabelNoPlace.translatesAutoresizingMaskIntoConstraints = false
        dateLabelNoPlace.numberOfLines = 1
        dateLabelNoPlace.adjustsFontSizeToFitWidth = false
        dateLabelNoPlace.font = UIFont.piwigoFontSemiBold()
        dateLabelNoPlace.textColor = UIColor.piwigoColorLeftLabel()

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
                self.dateLabel.text = dateLabelText
            }
            dateLabelNoPlace.text = ""
        } else {
            placeLabel.text = ""
            self.dateLabel.text = ""
            dateLabelNoPlace.text = dateLabelText
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
        dateLabelNoPlace.text = ""
        placeLabel.text = ""
    }
}
