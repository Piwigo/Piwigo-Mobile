//
//  DescriptionValueTransformer.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public class DescriptionValueTransformer: NSSecureUnarchiveFromDataTransformer {

    public override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    public override class func transformedValueClass() -> AnyClass {
        return NSAttributedString.self
    }
    
    public override class var allowedTopLevelClasses: [AnyClass] {
        return [NSAttributedString.self]
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            fatalError("Wrong data type: value must be a Data object; received \(type(of: value))")
        }
        return super.transformedValue(data)
    }
    
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let description = value as? NSAttributedString else {
            fatalError("Wrong data type: value must be a NSAttributedString object; received \(type(of: value))")
        }
        return super.reverseTransformedValue(description)
    }
}


extension DescriptionValueTransformer {
    static let name = NSValueTransformerName(String(describing: DescriptionValueTransformer.self))
    
    public static func register() {
        let transfomer = DescriptionValueTransformer()
        ValueTransformer.setValueTransformer(transfomer, forName: name)
    }
}
