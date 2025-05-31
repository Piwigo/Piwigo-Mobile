//
//  UploadRenameAction+DateFormat.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Date Format
// See http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns
public enum pwgDateFormat: Equatable, Hashable {
    public enum Year: String, CaseIterable, Hashable {
        case none
        case yy
        case yyyy
    }
    
    public enum Month: String, CaseIterable, Hashable {
        case none
        case MM
        case MMM
        case MMMM
    }
    
    public enum Day: String, CaseIterable, Hashable {
        case none
        case dd
        case ddd
        case EEE
        case EEEE
    }
    
    
    case year(format: Year)
    case month(format: Month)
    case day(format: Day)
    case separator(format: pwgSeparator)
        
    public var asString: String {
        switch self {
        case .year(format: let format):
            return format.rawValue
        case .month(format: let format):
            return format.rawValue
        case .day(format: let format):
            return format.rawValue
        case .separator(format: let format):
            return format.rawValue
        }
    }
    
    public init?(_ asString: String) {
        switch asString {
        case Year.yy.rawValue:
            self = .year(format: .yy)
        case Year.yyyy.rawValue:
            self = .year(format: .yyyy)
        
        case Month.MM.rawValue:
            self = .month(format: .MM)
        case Month.MMM.rawValue:
            self = .month(format: .MMM)
        case Month.MMMM.rawValue:
            self = .month(format: .MMMM)
        
        case Day.dd.rawValue:
            self = .day(format: .dd)
        case Day.ddd.rawValue:
            self = .day(format: .ddd)
        case Day.EEE.rawValue:
            self = .day(format: .EEE)
        case Day.EEEE.rawValue:
            self = .day(format: .EEEE)
        
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

public extension Array where Element == pwgDateFormat {
    // Convert an array of pwgDateFormat to a string of format strings separated by "|"
    var asString: String {
        // Get separator from list
        let separator: pwgDateFormat = self.filter({
            if case .separator(format: _) = $0 { return true }
            return false
        }).first  ?? .separator(format: .none)
        
        // Get list without separators
        let noSeparatorList: [pwgDateFormat] = self.filter({
            if case .separator(format: _) = $0 { return false }
            return true
        })
        
        // Insert separators between year, month and day formats
        var finalList: [pwgDateFormat] = []
        for index in stride(from: 0, to: noSeparatorList.count, by: 1) {
            // Only keep useful formats
            if [.year(format: .none), .month(format: .none), .day(format: .none)].contains(noSeparatorList[index]) {
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
    // Returns an array of pwgDateFormat from a string
    // This array contains the year, month and day formats in some order,
    // followed by the separator (required by DateFormatSelectorViewController)
    var asPwgDateFormats: [pwgDateFormat] {
        // Convert format string to a list of pwgDateFormat
        let stringList: [String] = self.split(separator: "|").map({ String($0) })
        let formatList: [pwgDateFormat] = stringList.compactMap({ pwgDateFormat($0) })
        
        // Get separator from the list
        let separator: pwgDateFormat = formatList.filter({
            if case .separator(format: _) = $0 { return true }
            return false
        }).first  ?? .separator(format: .none)
        
        // Get list without separators
        var noSeparatorList: [pwgDateFormat] = formatList.filter({
            if case .separator(format: _) = $0 { return false }
            return true
        })
        
        // Append missing year, month or day formats
        var missingFormats: [pwgDateFormat] = [.year(format: .none),
                                               .month(format: .none),
                                               .day(format: .none)]
        noSeparatorList.forEach { format in
            switch format {
            case .year(format: _):
                missingFormats.removeAll { $0 == .year(format: .none) }
            case .month(format: _):
                missingFormats.removeAll { $0 == .month(format: .none) }
            case .day(format: _):
                missingFormats.removeAll { $0 == .day(format: .none) }
            default:
                break
            }
        }
        noSeparatorList += missingFormats
        return noSeparatorList + [separator]
    }
}
