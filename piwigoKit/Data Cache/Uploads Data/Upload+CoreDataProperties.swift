//
//  Upload+CoreDataProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
//  Properties of the Upload entity.
//

import Foundation
import CoreData

extension Upload {

    public class func fetchRequest() -> NSFetchRequest<Upload> {
        return NSFetchRequest<Upload>(entityName: "Upload")
    }

    @NSManaged public var author: String
    @NSManaged public var category: Int64
    @NSManaged public var comment: String
    @NSManaged public var compressImageOnUpload: Bool
    @NSManaged public var creationDate: TimeInterval
    @NSManaged public var defaultPrefix: String
    @NSManaged public var deleteImageAfterUpload: Bool
    @NSManaged public var fileName: String
    @NSManaged public var imageId: Int64
    @NSManaged public var imageName: String
    @NSManaged public var isVideo: Bool
    @NSManaged public var localIdentifier: String
    @NSManaged public var md5Sum: String
    @NSManaged public var mimeType: String
    @NSManaged public var photoQuality: Int16
    @NSManaged public var photoMaxSize: Int16
    @NSManaged public var videoMaxSize: Int16
    @NSManaged public var prefixFileNameBeforeUpload: Bool
    @NSManaged public var privacyLevel: Int16
    @NSManaged public var requestDate: TimeInterval
    @NSManaged public var requestError: String
    @NSManaged public var requestSectionKey: String
    @NSManaged public var requestState: Int16
    @NSManaged public var resizeImageOnUpload: Bool
    @NSManaged public var serverFileTypes: String
    @NSManaged public var serverPath: String
    @NSManaged public var stripGPSdataOnUpload: Bool
    @NSManaged public var tagIds: String
    @NSManaged public var markedForAutoUpload: Bool
}
