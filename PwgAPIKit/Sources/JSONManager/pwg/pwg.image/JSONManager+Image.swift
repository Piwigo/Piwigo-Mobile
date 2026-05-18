//
//  JSONManager+Image.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit

public extension JSONManager {
    
    @concurrent
    func rotateImage(withID imageID: Int64, by angle: Double) async throws(PwgKitError) {
        // Prepare parameters for rotating image
        let paramsDict: [String : Any] = ["image_id"  : imageID,
                                          "angle"     : angle * 180.0 / .pi,
                                          "pwg_token" : ServerVars.shared.pwgToken,
                                          "rotate_hd" : true]
        
        _ = try await postRequest(withMethod: pwgImageRotate, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: ImageRotateJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
}
