//
//  Sizes+CoreDataProperties.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//

public import Foundation
public import CoreData


public typealias SizesCoreDataPropertiesSet = NSSet

extension Sizes {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Sizes> {
        return NSFetchRequest<Sizes>(entityName: "Sizes")
    }

    @NSManaged public var square: Resolution?
    @NSManaged public var thumb: Resolution?
    @NSManaged public var xxsmall: Resolution?
    @NSManaged public var xsmall: Resolution?
    @NSManaged public var small: Resolution?
    @NSManaged public var medium: Resolution?
    @NSManaged public var large: Resolution?
    @NSManaged public var xlarge: Resolution?
    @NSManaged public var xxlarge: Resolution?
    @NSManaged public var xxxlarge: Resolution?
    @NSManaged public var xxxxlarge: Resolution?
    @NSManaged public var image: Image?

}

extension Sizes : Identifiable {

}
