//
//  IntentHandler.swift
//  piwigoIntents
//
//  Created by Eddy Lelièvre-Berna on 19/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Intents

@available(iOSApplicationExtension 13.0, *)
class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is UploadPhotosIntent:
            return UploadPhotosHandler()
        default:
            fatalError("!!! No handler for this intent !!!")
        }
    }
}
