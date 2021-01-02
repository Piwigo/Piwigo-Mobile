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
    class func clearAllCache(exceptCategories: Bool,
                             completionHandler: @escaping () -> Void) {
        
        // Tags
        let tagsProvider : TagsProvider = TagsProvider()
        tagsProvider.clearTags()

        // Locations with place names
        LocationsProvider.sharedInstance().clearLocations()

        // Data
        TagsData.sharedInstance().clearCache()
        if !exceptCategories { CategoriesData.sharedInstance().clearCache() }

        // URL requests
        Model.sharedInstance()?.imageCache.removeAllCachedResponses()
        Model.sharedInstance()?.thumbnailCache.removeAllImages()
        
        // Clean up /tmp directory
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectoryImmediately(true)
        
        // Job done
        completionHandler()
    }
}
