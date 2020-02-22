//
//  ClearCache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

@objc
class ClearCache: NSObject {
    
    @objc
    class func clearAllCache() {
        
        /**
         The TagsProvider that fetches tag data, saves it to Core Data,
         and serves it to this table view.
         */
//        let dataProvider : TagsProvider = TagsProvider(completionClosure: {})
        let dataProvider : TagsProvider = TagsProvider()
        dataProvider.clearTags()

        // Data
        TagsData.sharedInstance().clearCache()
        CategoriesData.sharedInstance().clearCache()
        LocationsData.sharedInstance().clearCache()

        // URL requests
        URLCache.shared.removeAllCachedResponses()
    }
}
