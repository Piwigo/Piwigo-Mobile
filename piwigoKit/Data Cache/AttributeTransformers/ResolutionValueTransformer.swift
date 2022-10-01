//
//  ResolutionValueTransformer.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import UIKit

public class ResolutionValueTransformer: NSSecureUnarchiveFromDataTransformer {

    public override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    public override class func transformedValueClass() -> AnyClass {
        return Resolution.self
    }
    
    public override class var allowedTopLevelClasses: [AnyClass] {
        return [Resolution.self, NSURL.self]
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            fatalError("Wrong data type: value must be a Data object; received \(type(of: value))")
        }
        guard let resolution = super.transformedValue(data) as? Resolution else {
            return nil
        }
        
        // Return absolute URL from data containing relative URL
        if let relativeURL = resolution.url,
           relativeURL.scheme == nil, relativeURL.host == nil,
           let path = relativeURL.absoluteString, path.isEmpty == false,
           let absoluteURL = NSURL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(path)") {
            resolution.url = absoluteURL
        }
        return resolution
    }

    override public func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let resolution = value as? Resolution else {
            fatalError("Wrong data type: value must be a Resolution object; received \(type(of: value))")
        }
        
        // Store relative URL as Data to save space and because the scheme and host might changed in future
        guard let absoluteURL = resolution.url else {
            return super.reverseTransformedValue(resolution)
        }
        let serverPath = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"
        if var path = absoluteURL.absoluteString, path.hasPrefix(serverPath) {
            path.removeFirst(serverPath.count)
            let newResolution = Resolution(imageWidth: resolution.width,
                                           imageHeight: resolution.height,
                                           imagePath: path)
            return super.reverseTransformedValue(newResolution)
        }
        return super.reverseTransformedValue(resolution)
    }
}


extension ResolutionValueTransformer{
    
    static let name = NSValueTransformerName(String(describing: ResolutionValueTransformer.self))
    
    public static func register() {
        let transfomer = ResolutionValueTransformer()
        ValueTransformer.setValueTransformer(transfomer, forName: name)
    }
}
