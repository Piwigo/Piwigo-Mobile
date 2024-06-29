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

@objc protocol LocalImagesHeaderDelegate: NSObjectProtocol {
    func didSelectImagesOfSection(_ section: Int)
}

class LocalImagesHeaderReusableView: UICollectionReusableView {
    
    var section = 0
    private var locationHash = Int.zero

    @objc weak var headerDelegate: LocalImagesHeaderDelegate?
    
    @IBOutlet weak var mainLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var selectButton: UIButton!
    
    func configure(with images: [PHAsset], section: Int, selectState: SelectButtonState) {
        
        // General settings
        backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)

        // Keep section for future use
        self.section = section
        
        // Date and place name of location
        mainLabel.textColor = .piwigoColorLeftLabel()
        detailLabel.textColor = .piwigoColorRightLabel()

        // Get date labels from images in section
        let oldest = DateUtilities.refDateInterval   // i.e. unknown date
        let dateIntervals = images.map { $0.creationDate?.timeIntervalSinceReferenceDate ?? oldest}
        let dates = AlbumUtilities.getDateLabels(for: dateIntervals)
        self.mainLabel.text = dates.0

        // Set labels from dates and place name
        if images.isEmpty {
            self.detailLabel.text = dates.1
        } else {
            // Determine location from images in section
            let location = getLocation(of: images)
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

        // Select/deselect button
        selectButton.layer.cornerRadius = 13.0
        selectButton.setTitle(forState: selectState)
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
        headerDelegate?.didSelectImagesOfSection(section)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        detailLabel.text = ""
        mainLabel.text = ""
        selectButton.setTitle("", for: .normal)
        selectButton.backgroundColor = .piwigoColorBackground()
    }

    
    // MARK: Utilities
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
