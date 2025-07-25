//
//  ImageFileType.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/07/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public enum pwgImageFileType : Int16, CaseIterable {
    case image = 0
    case video
    case pdf
}

extension Image
{
    public var isImage: Bool {
        return pwgImageFileType(rawValue: self.fileType) == .image
    }
    
    public var isVideo: Bool {
        return pwgImageFileType(rawValue: self.fileType) == .video
    }
    
    public var isPDF: Bool {
        return pwgImageFileType(rawValue: self.fileType) == .pdf
    }
    
    public var isNotImage: Bool {
        return isVideo || isPDF
    }
}
