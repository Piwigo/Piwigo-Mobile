//
//  Location+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
//  Properties of the Location entity.
//

import Foundation
import CoreData

extension Location {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Location> {
        return NSFetchRequest<Location>(entityName: "Location")
    }

    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var placeName: String
    @NSManaged public var radius: Double
    @NSManaged public var streetName: String

}
