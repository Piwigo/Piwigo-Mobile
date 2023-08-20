//
//  Video.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/07/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

struct Video: Hashable {
    
    let pwgID: Int64
    let pwgURL: URL
    let cacheURL: URL
    let title: String
    let artwork: UIImage
    var duration = TimeInterval(0)
    var resumeTime = TimeInterval(0)
    
    init(pwgID: Int64, pwgURL: URL, cacheURL: URL, title: String, artwork: UIImage) {
        self.pwgID = pwgID
        self.pwgURL = pwgURL
        self.cacheURL = cacheURL.appendingPathExtension("mov")
        self.title = title
        self.artwork = artwork
    }
}


// MARK: - Image Video Object
extension Image
{
    var video: Video? {
        if self.isVideo,
           let cacheURL = self.cacheURL(ofSize: .fullRes),
           let pwgURL = self.fullRes?.url {
            // Create video object
            let size = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            let artwork = self.cachedThumbnail(ofSize: size) ?? UIImage(named: "placeholderImage")!
            return Video(pwgID: self.pwgID, pwgURL: pwgURL as URL, cacheURL: cacheURL,
                         title: self.titleStr, artwork: artwork)
        }
        else {
            return nil
        }
    }
}
