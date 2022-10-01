//
//  RelativeURLValueTransformer.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 11/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public class RelativeURLValueTransformer: NSSecureUnarchiveFromDataTransformer {

    public override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    public override class func transformedValueClass() -> AnyClass {
        return NSURL.self
    }
    
    public override class var allowedTopLevelClasses: [AnyClass] {
        return [NSURL.self]
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            fatalError("Wrong data type: value must be a Data object; received \(type(of: value))")
        }
        guard let relativeURL = super.transformedValue(data) as? NSURL else {
            return nil
        }

        // Return absolute URL from data containing relative URL
        if relativeURL.scheme == nil, relativeURL.host == nil,
           let path = relativeURL.absoluteString, path.isEmpty == false,
           let absoluteURL = NSURL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(path)") {
            return absoluteURL
        }
        return relativeURL
    }
    
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let absoluteURL = value as? NSURL else {
            fatalError("Wrong data type: value must be a NSURL object; received \(type(of: value))")
        }
        
        // Store relative URL as Data to save space and because the scheme and host might changed in future
        let serverPath = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        if var path = absoluteURL.absoluteString, path.hasPrefix(serverPath) {
            path.removeFirst(serverPath.count)
            let relativeURL = NSURL(string: path) ?? absoluteURL
            return super.reverseTransformedValue(relativeURL)
        }
        return nil
    }
}


extension RelativeURLValueTransformer {
    
    static let name = NSValueTransformerName(String(describing: RelativeURLValueTransformer.self))
    
    public static func register() {
        let transfomer = RelativeURLValueTransformer()
        ValueTransformer.setValueTransformer(transfomer, forName: name)
    }
}
