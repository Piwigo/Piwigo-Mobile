//
//  KeychainUtilitiesObjc.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@objc class KeychainUtilitiesObjc: NSObject {
    
    @objc class func setPassword(_ password:String, forService service:String, account:String) {
        return KeychainUtilities.setPassword(password, forService: service, account: account)
    }
    
    @objc class func password(forService service:String, account:String) -> String {
        return KeychainUtilities.password(forService: service, account: account)
    }
    
    @objc class func deletePassword(forService service:String, account:String) {
        return KeychainUtilities.deletePassword(forService: service, account: account)
    }
}
