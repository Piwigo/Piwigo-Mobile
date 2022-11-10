//
//  ImageResolution.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public class Resolution: NSObject, NSSecureCoding {
    
    public static var supportsSecureCoding = true

    public var width: Int = 1
    public var height: Int = 1
    public var url: NSURL?
    public var uuid: String = ""
    
    enum Key: String {
        case width = "width"
        case height = "height"
        case url = "url"
        case uuid = "uuid"
    }

    init(imageWidth: Int, imageHeight: Int, imageURL: NSURL?, imageID: String? = nil) {
        width = imageWidth
        height = imageHeight
        url = imageURL
        uuid = imageID ?? UUID().uuidString
    }

    init(imageWidth: Int, imageHeight: Int, imagePath: String?, imageID: String? = nil) {
        width = imageWidth
        height = imageHeight
        url = NSURL(string: imagePath ?? "")
        uuid = imageID ?? UUID().uuidString
    }
    
    public required convenience init?(coder decoder: NSCoder) {
        let imageWidth = decoder.decodeInteger(forKey: Key.width.rawValue)
        let imageHeight = decoder.decodeInteger(forKey: Key.height.rawValue)
        let imageUrl = decoder.decodeObject(forKey: Key.url.rawValue)
        let imageID = decoder.decodeObject(forKey: Key.uuid.rawValue)
        self.init(imageWidth: imageWidth, imageHeight: imageHeight,
                  imageURL: imageUrl as? NSURL, imageID: imageID as? String)
    }

    public func encode(with coder: NSCoder) {
        coder.encode(width, forKey: Key.width.rawValue)
        coder.encode(height, forKey: Key.height.rawValue)
        coder.encode(url, forKey: Key.url.rawValue)
        coder.encode(uuid, forKey: Key.uuid.rawValue)
    }
}

extension Resolution {
    func isEqual(_ other: Resolution) -> Bool {
        if self.width == other.width,
           self.height == other.height,
           self.url?.absoluteString ?? "" == other.url?.absoluteString ?? "" {
            return true
        }
        return false
    }
}
