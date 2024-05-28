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
    weak var imageHeaderDelegate: ImageHeaderDelegate?

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

        // Determine location from images in section
        let location = getLocation(of: images)
        
        // Set up labels from dates and place name
        (placeLabel.text, dateLabel.text) = AlbumUtilities.getLabels(fromDate: dates.0, optionalDate: dates.1, location: location)
    }
    
    private func getLocation(of images: [Image]) -> CLLocation {
        // Initialise location of section with invalid location
        var verticalAccuracy = CLLocationAccuracy.zero
        if #available(iOS 14, *) {
            verticalAccuracy = kCLLocationAccuracyReduced
        } else {
            verticalAccuracy = kCLLocationAccuracyThreeKilometers
        }
        var locationForSection = CLLocation(coordinate: kCLLocationCoordinate2DInvalid,
                                            altitude: CLLocationDistance(0.0),
                                            horizontalAccuracy: CLLocationAccuracy(0.0),
                                            verticalAccuracy: CLLocationAccuracy(0.0),
                                            timestamp: Date())

        // Loop over images in section
        for image in images {

            // Any location data ?
            guard image.latitude != 0.0, image.longitude != 0.0 else {
                // Image has no valid location data => Next image
                continue
            }

            // Location found => Store if first found and move to next section
            if !CLLocationCoordinate2DIsValid(locationForSection.coordinate) {
                // First valid location => Store it
                locationForSection = CLLocation(latitude: image.latitude, longitude: image.longitude)
            } else {
                // Another valid location => Compare to first one
                let newLocation = CLLocation(latitude: image.latitude, longitude: image.longitude)
                let distance = locationForSection.distance(from: newLocation)
                
                // Similar location?
                let meanLatitude: CLLocationDegrees = (locationForSection.coordinate.latitude + newLocation.coordinate.latitude)/2
                let meanLongitude: CLLocationDegrees = (locationForSection.coordinate.longitude + newLocation.coordinate.longitude)/2
                let newCoordinate = CLLocationCoordinate2DMake(meanLatitude,meanLongitude)
                if distance < kCLLocationAccuracyBest {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyBest,
                                                    verticalAccuracy: verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyNearestTenMeters {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyNearestTenMeters,
                                                    verticalAccuracy: verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyHundredMeters {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyHundredMeters,
                                                    verticalAccuracy: verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyKilometer {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyKilometer,
                                                    verticalAccuracy: verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyThreeKilometers {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyThreeKilometers,
                                                    verticalAccuracy: verticalAccuracy,
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

    override func prepareForReuse() {
        super.prepareForReuse()
        
        dateLabel.text = ""
        placeLabel.text = ""
        selectButton.setTitle("", for: .normal)
        selectButton.backgroundColor = .piwigoColorBackground()
    }
}
