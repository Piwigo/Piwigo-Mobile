//
//  AutoUploadPhotosHandler.swift
//  piwigoIntents
//
//  Created by Eddy Lelièvre-Berna on 03/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

class AutoUploadPhotosHandler: NSObject, AutoUploadPhotosIntentHandling {
    
    func handle(intent: AutoUploadPhotosIntent, completion: @escaping (AutoUploadPhotosIntentResponse) -> Void) {
        print("•••>> AutoUploadPhotos shortcut launched ;-)")
        completion(AutoUploadPhotosIntentResponse.success(nberPhotos: 12))
    }
}
