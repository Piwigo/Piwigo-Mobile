//
//  UserDefaults+AppGroups.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

extension UserDefaults {

    // We use different App Groups:
    /// - Development: one chosen by the developer
    /// - Release: the official group.org.piwigo
    #if DEBUG
    private static let AppGroup = "group.net.lelievre-berna.piwigo"
    #else
    private static let AppGroup = "group.org.piwigo"
    #endif
    
    public static let dataSuite = { () -> UserDefaults in
        guard let dataSuite = UserDefaults(suiteName: AppGroup) else {
             fatalError("Could not load UserDefaults for app group \(AppGroup)")
        }
        
        return dataSuite
    }()
}


// A type safe property wrapper to set and get values from UserDefaults with support for defaults values.
/// https://github.com/guillermomuntaner/Burritos/blob/master/Sources/UserDefault/UserDefault.swift
@propertyWrapper
public struct UserDefault<Value: PropertyListValue> {
    public let defaultKey: String
    public let defaultValue: Value
    public var userDefaults: UserDefaults
    
    public init(_ key: String, defaultValue: Value, userDefaults: UserDefaults = .standard) {
        self.defaultKey = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    public var wrappedValue: Value {
        get {
            return userDefaults.object(forKey: defaultKey) as? Value ?? defaultValue
        }
        set {
            userDefaults.set(newValue, forKey: defaultKey)
        }
    }
}

// A type than can be stored in `UserDefaults`.
//
/// - From UserDefaults;
/// The value parameter can be only property list objects: NSData, NSString, NSNumber, NSDate, NSArray, or NSDictionary.
/// For NSArray and NSDictionary objects, their contents must be property list objects. For more information, see What is a
/// Property List? in Property List Programming Guide.public protocol PropertyListValue {}
public protocol PropertyListValue {}

extension String: PropertyListValue {}
extension NSString: PropertyListValue {}

extension Bool: PropertyListValue {}
extension Int: PropertyListValue {}
extension Int16: PropertyListValue {}
extension UInt: PropertyListValue {}
extension UInt16: PropertyListValue {}
extension UInt32: PropertyListValue {}

extension TimeInterval: PropertyListValue {}
