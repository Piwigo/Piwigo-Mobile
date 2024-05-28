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
import piwigoKit

enum SelectButtonState : Int {
    case none
    case select
    case deselect
}

@objc protocol LocalImagesHeaderDelegate: NSObjectProtocol {
    func didSelectImagesOfSection(_ section: Int)
}

class LocalImagesHeaderReusableView: UICollectionReusableView {
    
    var section = 0

    // MARK: - View
    
    @objc weak var headerDelegate: LocalImagesHeaderDelegate?
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var placeLabel: UILabel!

    func configure(with images: [PHAsset], section: Int, selectState: SelectButtonState) {
        
        // General settings
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)

        // Keep section for future use
        self.section = section
        
        // Date label used when place name known
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.numberOfLines = 1
        dateLabel.adjustsFontSizeToFitWidth = false
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .piwigoColorRightLabel()

        // Place name of location
        placeLabel.translatesAutoresizingMaskIntoConstraints = false
        placeLabel.numberOfLines = 1
        placeLabel.adjustsFontSizeToFitWidth = false
        placeLabel.font = .systemFont(ofSize: 15, weight: .medium)
        placeLabel.textColor = .piwigoColorLeftLabel()

        // Get date labels from images in section
        var dates = AlbumUtilities.getDateLabels(for: images.first?.creationDate,
                                                 to: images.last?.creationDate)
        // Determine location from images in section
        let location = getLocation(of: images)
        
        // Set up labels from dates and place name
        (placeLabel.text, dateLabel.text) = AlbumUtilities.getLabels(fromDate: dates.0, optionalDate: dates.1, location: location)

        // Select/deselect button
        selectButton.layer.cornerRadius = 13.0
        setButtonTitle(forState: selectState)
    }

    @IBAction func tappedSelectButton(_ sender: Any) {
        // Select/deselect images
        headerDelegate?.didSelectImagesOfSection(section)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        dateLabel.text = ""
        placeLabel.text = ""
        selectButton.setTitle("", for: .normal)
        selectButton.backgroundColor = .piwigoColorBackground()
    }

    
    // MARK: Utilities
    func setButtonTitle(forState state: SelectButtonState) {
        let title: String, bckgColor: UIColor
        switch state {
        case .select:
            title = String(format: "  %@  ", NSLocalizedString("selectAll", comment: "Select All"))
            bckgColor = .piwigoColorCellBackground()
        case .deselect:
            title = String(format: "  %@  ", NSLocalizedString("categoryImageList_deselectButton", comment: "Deselect"))
            bckgColor = .piwigoColorCellBackground()
        case .none:
            title = ""
            bckgColor = .clear
        }
        selectButton.backgroundColor = bckgColor
        selectButton.setTitle(title, for: .normal)
        selectButton.setTitleColor(.piwigoColorWhiteCream(), for: .normal)
        selectButton.accessibilityIdentifier = "SelectAll"
    }
        
    private func getLocation(of images: [PHAsset]) -> CLLocation {
        // Initialise location of section with invalid location
        var locationForSection = CLLocation(coordinate: kCLLocationCoordinate2DInvalid,
                                            altitude: CLLocationDistance(0.0),
                                            horizontalAccuracy: CLLocationAccuracy(0.0),
                                            verticalAccuracy: CLLocationAccuracy(0.0),
                                            timestamp: Date())

        // Loop over images in section
        for imageAsset in images {

            // Any location data ?
            guard let assetLocation = imageAsset.location else {
                // Image has no valid location data => Next image
                continue
            }

            // Location found => Store if first found and move to next section
            if !CLLocationCoordinate2DIsValid(locationForSection.coordinate) {
                // First valid location => Store it
                locationForSection = assetLocation
            } else {
                // Another valid location => Compare to first one
                let distance = locationForSection.distance(from: assetLocation)
                if distance <= locationForSection.horizontalAccuracy {
                    // Same location within horizontal accuracy
                    continue
                }
                // Still a similar location?
                let meanLatitude: CLLocationDegrees = (locationForSection.coordinate.latitude + assetLocation.coordinate.latitude)/2
                let meanLongitude: CLLocationDegrees = (locationForSection.coordinate.longitude + assetLocation.coordinate.longitude)/2
                let newCoordinate = CLLocationCoordinate2DMake(meanLatitude,meanLongitude)
                var newHorizontalAccuracy = kCLLocationAccuracyBestForNavigation
                let newVerticalAccuracy = max(locationForSection.verticalAccuracy, assetLocation.verticalAccuracy)
                if distance < kCLLocationAccuracyBest {
                    newHorizontalAccuracy = max(kCLLocationAccuracyBest, locationForSection.horizontalAccuracy)
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyNearestTenMeters {
                    newHorizontalAccuracy = max(kCLLocationAccuracyNearestTenMeters, locationForSection.horizontalAccuracy)
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyHundredMeters {
                    newHorizontalAccuracy = max(kCLLocationAccuracyHundredMeters, locationForSection.horizontalAccuracy)
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyKilometer {
                    newHorizontalAccuracy = max(kCLLocationAccuracyKilometer, locationForSection.horizontalAccuracy)
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyThreeKilometers {
                    newHorizontalAccuracy = max(kCLLocationAccuracyThreeKilometers, locationForSection.horizontalAccuracy)
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else {
                    // Above 3 km, we estimate that it is a different location
                    return locationForSection
                }
             }
        }
        
        return locationForSection
    }
}
