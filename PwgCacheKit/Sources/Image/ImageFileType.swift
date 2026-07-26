//
//  ImageFileType.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 19/07/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public enum pwgImageFileType : Int16, CaseIterable, Sendable {
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

    /// GIF files are stored with the 'image' file type,
    /// but only the full resolution file contains the animation.
    public var isGIF: Bool {
        return pwgImageFileType(rawValue: self.fileType) == .image
            && URL(fileURLWithPath: self.fileName).pathExtension.lowercased() == "gif"
    }
    
    /// EPS files are stored with the 'image' file type because they are displayed
    /// through the server-generated derivatives. However they have no full-resolution
    /// raster the app can request, so — like video and PDF — they are 'not an image'
    /// when selecting the optimum image size/URL (never .fullRes).
    public var isEPS: Bool {
        return pwgImageFileType(rawValue: self.fileType) == .image
            && ["eps", "epsf", "epsi"].contains(URL(fileURLWithPath: self.fileName).pathExtension.lowercased())
    }
    
    public var hasFullResThumbnail: Bool {
        return !(isVideo || isGIF || isPDF || isEPS)
    }
}
