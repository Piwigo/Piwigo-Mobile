//
//  Location+CoreDataClass.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Location entity.
//

import Foundation
import CoreData
import CoreLocation

public class Location: NSManagedObject {

    /**
     Updates a Location instance with the values from a LocationProperties.
     */
    func update(with locationProperties: LocationProperties) throws {
        
        // Update the location only if the latitude and longitude properties have values.
        guard let newLatitude = locationProperties.coordinate?.latitude,
            let newLongitude = locationProperties.coordinate?.longitude else {
                throw LocationError.missingData
        }
        latitude = newLatitude as Double
        longitude = newLongitude as Double
        radius = (locationProperties.radius ?? kCLLocationAccuracyThreeKilometers) as Double
        placeName = locationProperties.placeName ?? ""
        streetName = locationProperties.streetName ?? ""
    }
}

/**
 A struct for manipulating Piwigo locations.
 All members are optional in case they are missing from the data.
*/
struct LocationProperties
{
    var coordinate: CLLocationCoordinate2D?     //
    var radius: CLLocationDistance?             //
    var placeName: String?                      //
    var streetName: String?                     //
}
