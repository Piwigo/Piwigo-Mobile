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
    
    let pwgURL: URL
    let cacheURL: URL
    let title: String
//    let duration: TimeInterval
    var resumeTime: TimeInterval
    
    init(pwgURL: URL, cacheURL: URL, title: String, resumeTime: TimeInterval = 0) {
        self.pwgURL = pwgURL
        self.cacheURL = cacheURL.appendingPathExtension("mov")
        self.title = title
        self.resumeTime = resumeTime
    }
}
