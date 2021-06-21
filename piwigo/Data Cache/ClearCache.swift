//
//  ClearCache.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@objc
class ClearCache: NSObject {
    
    @objc
    class func clearAllCache(exceptCategories: Bool,
                             completionHandler: @escaping () -> Void) {
        
        // Tags
        TagsProvider().clearTags()

        // Locations with place names
        LocationsProvider().clearLocations()

        // Data
        TagsData.sharedInstance().clearCache()
        if !exceptCategories { CategoriesData.sharedInstance().clearCache() }

        // URL requests
        NetworkVarsObjc.shared.imageCache?.removeAllCachedResponses()
        NetworkVarsObjc.shared.thumbnailCache?.removeAllImages()
        
        // Clean up /tmp directory
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectory(immediately: true)
        
        // Job done
        completionHandler()
    }
}
