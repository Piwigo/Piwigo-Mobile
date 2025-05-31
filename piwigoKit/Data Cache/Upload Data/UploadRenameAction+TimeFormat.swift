//
//  UploadRenameAction+TimeFormat.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Time Format
// See http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns
public enum pwgTimeFormat: Equatable, Hashable {
    public enum Hour: String, CaseIterable, Hashable {
        case none
        case hha
        case HH
    }
    
    public enum Minute: String, CaseIterable, Hashable {
        case none
        case mm
    }
    
    public enum Second: String, CaseIterable, Hashable {
        case none
        case ss
        case ssSSS = "ss.SSS"
    }
        
    case hour(format: Hour)
    case minute(format: Minute)
    case second(format: Second)
    case separator(format: pwgSeparator)
        
    public var asString: String {
        switch self {
        case .hour(format: let format):
            return format.rawValue
        case .minute(format: let format):
            return format.rawValue
        case .second(format: let format):
            return format.rawValue
        case .separator(format: let format):
            return format.rawValue
        }
    }
    
    public init?(_ asString: String) {
        switch asString {
        case Hour.hha.rawValue:
            self = .hour(format: .hha)
        case Hour.HH.rawValue:
            self = .hour(format: .HH)
        
        case Minute.mm.rawValue:
            self = .minute(format: .mm)
        
        case Second.ss.rawValue:
            self = .second(format: .ss)
        case Second.ssSSS.rawValue:
            self = .second(format: .ssSSS)
        
        case pwgSeparator.dash.rawValue:
            self = .separator(format: .dash)
        case pwgSeparator.underscore.rawValue:
            self = .separator(format: .underscore)
        case pwgSeparator.space.rawValue:
            self = .separator(format: .space)
        case pwgSeparator.plus.rawValue:
            self = .separator(format: .plus)
        default:
            return nil
        }
    }
}

public extension Array where Element == pwgTimeFormat {
    // Convert an array of pwgTimeFormat to a string of format strings separated by "|"
    var asString: String {
        // Get separator from list
        let separator: pwgTimeFormat = self.filter({
            if case .separator(format: _) = $0 { return true }
            return false
        }).first  ?? .separator(format: .none)
        
        // Get list without separators
        let noSeparatorList: [pwgTimeFormat] = self.filter({
            if case .separator(format: _) = $0 { return false }
            return true
        })
        
        // Insert separators between hour, minute and second formats
        var finalList: [pwgTimeFormat] = []
        for index in stride(from: 0, to: noSeparatorList.count, by: 1) {
            // Only keep useful formats
            if [.hour(format: .none), .minute(format: .none), .second(format: .none)].contains(noSeparatorList[index]) {
                continue
            }
            // Append separator if needed
            if finalList.isEmpty == false, separator != .separator(format: .none) {
                finalList.append(separator)
            }
            // Append format and separator if not the last format
            finalList.append(noSeparatorList[index])
            
        }
        return finalList.map(\.asString).filter({ $0.isEmpty == false }).joined(separator: "|")
    }
}

public extension String {
    // Returns an array of pwgTimeFormat from a string
    // This array contains the hour, minute and second formats in some order,
    // followed by the separator (required by TimeFormatSelectorViewController)
    var asPwgTimeFormats: [pwgTimeFormat] {
        // Convert format string to a list of pwgTimeFormat
        let stringList: [String] = self.split(separator: "|").map({ String($0) })
        let formatList: [pwgTimeFormat] = stringList.compactMap({ pwgTimeFormat($0) })
        
        // Get separator from the list
        let separator: pwgTimeFormat = formatList.filter({
            if case .separator(format: _) = $0 { return true }
            return false
        }).first  ?? .separator(format: .none)
        
        // Get list without separators
        var noSeparatorList: [pwgTimeFormat] = formatList.filter({
            if case .separator(format: _) = $0 { return false }
            return true
        })
        
        // Append missing year, month or day formats
        var missingFormats: [pwgTimeFormat] = [.hour(format: .none),
                                               .minute(format: .none),
                                               .second(format: .none)]
        noSeparatorList.forEach { format in
            switch format {
            case .hour(format: _):
                missingFormats.removeAll { $0 == .hour(format: .none) }
            case .minute(format: _):
                missingFormats.removeAll { $0 == .minute(format: .none) }
            case .second(format: _):
                missingFormats.removeAll { $0 == .second(format: .none) }
            default:
                break
            }
        }
        noSeparatorList += missingFormats
        return noSeparatorList + [separator]
    }
}
