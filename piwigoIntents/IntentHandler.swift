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
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        switch intent {
        case is AutoUploadPhotosIntent:
            return AutoUploadPhotosHandler()
        default:
            fatalError("!!! No handler for this intent !!!")
        }
    }
}
