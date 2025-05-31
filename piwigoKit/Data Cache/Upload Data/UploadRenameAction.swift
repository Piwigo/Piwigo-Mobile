//
//  UploadRenameAction.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 01/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: Rename Actions
/* Action types are listed in the ActionType enumeration below where:
    - the type identifies the action meaning, e.g. addText.
    - the Int raw value gives the first case a raw value of 1
      corresponding to the index used by the tableView(_: cellForRowAt:) method
      to present actions after the intial row allowing to enable/disable a series.

   Actions are identified by their type and the style which is a string defining
   the way an action is performed:
    - addText: adds the string provided by the user, e.g. "prefix-"
    - addAlbum: adds the album name to which photos are uploaded
    - addDate: adds the creation date in the wanted format, e.g. "YYYY-MM-DD"
    - addTime: adds the creation time in the wanted format, e.g. "HH-mm-ss"
    - addCounter: adds a number in the wanted fomat, e.g. "(0000)"
      The starting value of the counter is stored in UploadVars.shared.????

   The following convenience properties are also provided:
    - index is the index of the row to be used in the tableView(_: cellForRowAt:) method.
    - name is the action name displayed in each row with the left label.
        
    Actions are distributed over the 3 sections: .prefix, .replace and .suffix,
    and stored for convenience in 3 action lists and in the order chosen by the user.
    
    When storing a series of actions with @UserDefault, each action is converted
    to a string "<key>:<value>" where:
    - <key> is the Int mentioned above and identifying the action type,
    - <value> is a base-64 encoded value of the action style.
 
    "<key>:<value>" strings are separated by "," and stored is the order chosen by
    the user for renaming file names.
 */
public struct RenameAction: Hashable {
    // Enumeration of action types
    public enum ActionType: Int, CaseIterable, Comparable {
        case addText = 1    // A series of actions is enabled/disabled using row 0.
        case addAlbum
        case addDate
        case addTime
        case addCounter
        
        public var name: String {
            switch self {
            case .addText:
                return NSLocalizedString("Text", comment: "Text")
            case .addAlbum:
                return NSLocalizedString("createNewAlbum_placeholder", comment: "Album Name")
            case .addDate:
                return NSLocalizedString("editImageDetails_dateCreation", comment: "Creation Date")
            case .addTime:
                return NSLocalizedString("editImageDetails_timeCreation", comment: "Creation Time")
            case .addCounter:
                return NSLocalizedString("Counter", comment: "Counter")
            }
        }

        public static func < (lhs: ActionType, rhs: ActionType) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // Initialise an action with a default style
    public var type: ActionType
    public var style: String
    public init(type: ActionType, style: String? = nil) {
        self.type = type
        switch self.type {
        case .addText:
            self.style = style ?? ""
        case .addAlbum:
            self.style = NSLocalizedString("categorySelection_title", comment: "Album")
        case .addDate:
            let dateFormats: [pwgDateFormat] = [.year(format: .yyyy), .separator(format: .dash),
                                                .month(format: .MM), .separator(format: .dash),
                                                .day(format: .dd)]
            self.style = style ?? dateFormats.asString
        case .addTime:
            let timeFormats: [pwgTimeFormat] = [.hour(format: .HH), .separator(format: .dash),
                                                .minute(format: .mm), .separator(format: .dash),
                                                .second(format: .ss)]
            self.style = style ?? timeFormats.asString
        case .addCounter:
            let counterFormat: [pwgCounterFormat] = [.prefix(format: .none),
                                                     .digits(format: .four),
                                                     .suffix(format: .none)]
            self.style = style ?? counterFormat.asString
        }
    }
    
    // Convenience properties
    public var index: Int {
        return self.type.rawValue
    }
    public var name: String {
        return self.type.name
    }
    
    // Make this struct hashable
    public static func == (lhs: RenameAction, rhs: RenameAction) -> Bool {
        return lhs.type == rhs.type && lhs.style == rhs.style
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(style)
    }
}


// MARK: - Rename File Action Lists
public typealias RenameActionList = [RenameAction]

extension RenameActionList {
    // Returns encoded string from action list
    public var encodedString: String {
        var encodedStringList: [String] = []
        for action in self {
            guard let encodedString = action.style.base64Encoded else { continue }
            encodedStringList.append("\(action.index):\(encodedString)")
        }
        return encodedStringList.joined(separator: ",")
    }
}


// MARK: - Rename File Methods
public extension String {
    // Returns an action list from default settings
    var actions: RenameActionList {
        var actions: RenameActionList = []
        let encodedStringList: [String] = self.components(separatedBy: ",").filter { !$0.isEmpty }
        for encodedString in encodedStringList {
            let encodedStringComponents = encodedString.components(separatedBy: ":")
            if encodedStringComponents.count == 2,
               let intValue = Int(encodedStringComponents[0]),
               let actionType = RenameAction.ActionType(rawValue: intValue),
               let decodedString = encodedStringComponents[1].base64Decoded {
                actions.append(RenameAction(type: actionType, style: decodedString))
            }
        }
        return actions
    }
    
    // Renames self by applying actions
    mutating func rename(withPrefixActions prefixActions: RenameActionList,
                         replaceActions: RenameActionList,
                         suffixActions: RenameActionList,
                         albumName: String = NSLocalizedString("categorySelection_title", comment: "Album"),
                         date: Date, counter: Int) {
        // Extract name and extension
        var fileName: String = ""
        var fileExt: String = ""
        if let index = self.lastIndex(of: ".") {
            fileName = String(self[..<index])
            fileExt = String(self[index...])
        } else {
            fileName = self
        }
        
        // Replace file name
        if UploadVars.shared.replaceFileNameBeforeUpload {
            fileName = ""
            for action in replaceActions {
                switch action.type {
                case .addText:
                    fileName += action.style
                case .addAlbum:
                    fileName += albumName
                case .addDate:
                    let formatter: DateFormatter = DateUtilities.pwgDateFormatter
                    formatter.dateFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName += formatter.string(from: date)
                case .addTime:
                    let formatter: DateFormatter = DateUtilities.pwgDateFormatter
                    formatter.dateFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName += formatter.string(from: date)
                case .addCounter:
                    let formatter: NumberFormatter = NumberFormatter()
                    formatter.numberStyle = .none
                    formatter.positiveFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName += formatter.string(from: NSNumber(value: counter)) ?? ""
                }
            }
        }
        
        // Prefix file name
        if UploadVars.shared.prefixFileNameBeforeUpload {
            for action in prefixActions .reversed() {
                switch action.type {
                case .addText:
                    fileName = "\(action.style)\(fileName)"
                case .addAlbum:
                    fileName = "\(albumName)\(fileName)"
                case .addDate:
                    let formatter: DateFormatter = DateUtilities.pwgDateFormatter
                    formatter.dateFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName = "\(formatter.string(from: date))\(fileName)"
                case .addTime:
                    let formatter: DateFormatter = DateUtilities.pwgDateFormatter
                    formatter.dateFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName = "\(formatter.string(from: date))\(fileName)"
                case .addCounter:
                    let formatter: NumberFormatter = NumberFormatter()
                    formatter.numberStyle = .none
                    formatter.positiveFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName = "\(formatter.string(from: NSNumber(value: counter)) ?? "")\(fileName)"
                }
            }
        }
        
        // Suffix file name
        if UploadVars.shared.suffixFileNameBeforeUpload {
            for action in suffixActions {
                switch action.type {
                case .addText:
                    fileName = "\(fileName)\(action.style)"
                case .addAlbum:
                    fileName = "\(fileName)\(albumName)"
                case .addDate:
                    let formatter: DateFormatter = DateUtilities.pwgDateFormatter
                    formatter.dateFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName = "\(fileName)\(formatter.string(from: date))"
                case .addTime:
                    let formatter: DateFormatter = DateUtilities.pwgDateFormatter
                    formatter.dateFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName = "\(fileName)\(formatter.string(from: date))"
                case .addCounter:
                    let formatter: NumberFormatter = NumberFormatter()
                    formatter.numberStyle = .none
                    formatter.positiveFormat = action.style.replacingOccurrences(of: "|", with: "")
                    fileName = "\(fileName)\(formatter.string(from: NSNumber(value: counter)) ?? "")"
                }
            }
        }
        
        // Change case of extension
        if UploadVars.shared.changeCaseOfFileExtension {
            switch UploadVars.shared.caseOfFileExtension {
            case FileExtCase.lowercase.rawValue:
                fileName += fileExt.lowercased()
            case FileExtCase.uppercase.rawValue:
                fileName += fileExt.uppercased()
            default:
                break
            }
        } else {
            fileName += fileExt
        }
        
        self = fileName
    }
    
    /// Assuming the current string is base64 encoded, this property returns a String
    /// initialized by converting the current string into Unicode characters, encoded to
    /// utf8. If the current string is not base64 encoded, nil is returned instead.
    var base64Decoded: String? {
        guard let base64 = Data(base64Encoded: self, options: []) else { return nil }
        let utf8 = String(data: base64, encoding: .utf8)
        return utf8
    }
    
    /// Returns a base64 representation of the current string, or nil if the
    /// operation fails.
    var base64Encoded: String? {
        let utf8 = self.data(using: .utf8)
        let base64 = utf8?.base64EncodedString()
        return base64
    }
}
