//
//  UploadRenameAction+CounterFormat.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Counter Format
// See https://www.unicode.org/reports/tr35/tr35-dates.html#Date_Format_Patterns
public enum pwgCounterFormat: Equatable, Hashable {
    public enum Prefix: String, CaseIterable, Hashable {
        case none           = ""
        case round          = "("
        case square         = "["
        case curly          = "{"
        case angled         = "<"
        
        public var index: Int {
            return Prefix.allCases.firstIndex(of: self)! - 1
        }
    }
    
    public enum Digits: String, CaseIterable, Hashable {
        case one            = "0"
        case two            = "00"
        case three          = "000"
        case four           = "0000"
        case five           = "00000"
        case six            = "000000"
        case seven          = "0000000"
        case eight          = "00000000"
    }
    
    public enum Suffix: String, CaseIterable, Hashable {
        case none           = ""
        case round          = ")"
        case square         = "]"
        case curly          = "}"
        case angled         = ">"
        
        public var index: Int {
            return Suffix.allCases.firstIndex(of: self)! - 1
        }
    }

    case prefix(format: Prefix)
    case digits(format: Digits)
    case suffix(format: Suffix)
    
    public var asString: String {
        switch self {
        case .prefix(format: let format):
            return format.rawValue
        case .digits(format: let format):
            return format.rawValue
        case .suffix(format: let format):
            return format.rawValue
        }
    }
    
    public init?(_ asString: String) {
        switch asString {
        case Prefix.round.rawValue:
            self = .prefix(format: .round)
        case Prefix.square.rawValue:
            self = .prefix(format: .square)
        case Prefix.curly.rawValue:
            self = .prefix(format: .curly)
        case Prefix.angled.rawValue:
            self = .prefix(format: .angled)
        
        case Digits.one.rawValue:
            self = .digits(format: .one)
        case Digits.two.rawValue:
            self = .digits(format: .two)
        case Digits.three.rawValue:
            self = .digits(format: .three)
        case Digits.four.rawValue:
            self = .digits(format: .four)
        case Digits.five.rawValue:
            self = .digits(format: .five)
        case Digits.six.rawValue:
            self = .digits(format: .six)
        case Digits.seven.rawValue:
            self = .digits(format: .seven)
        case Digits.eight.rawValue:
            self = .digits(format: .eight)
        
        case Suffix.round.rawValue:
            self = .suffix(format: .round)
        case Suffix.square.rawValue:
            self = .suffix(format: .square)
        case Suffix.curly.rawValue:
            self = .suffix(format: .curly)
        case Suffix.angled.rawValue:
            self = .suffix(format: .angled)
        default:
            return nil
        }
    }
}

public extension Array where Element == pwgCounterFormat {
    // Convert an array of pwgCounterFormat to a string of format strings separated by "|"
    var asString: String {
        // Get prefix from list
        let prefix: pwgCounterFormat = self.filter({
            if case .prefix(format: _) = $0 { return true }
            return false
        }).first  ?? .prefix(format: .none)
        
        // Get number format from list
        let number: pwgCounterFormat = self.filter({
            if case .digits(format: _) = $0 { return true }
            return false
        }).first  ?? .digits(format: .one)
        
        // Get suffix from list
        let suffix: pwgCounterFormat = self.filter({
            if case .suffix(format: _) = $0 { return true }
            return false
        }).first  ?? .suffix(format: .none)
        
        // Return
        let finalList: [pwgCounterFormat] = [prefix, number, suffix]
        return finalList.map(\.asString).filter({ $0.isEmpty == false }).joined(separator: "|")
    }
}

public extension String {
    // Returns an array of pwgCounterFormat from a string
    // This array contains the prefix, number and suffix formats in this order
    var asPwgCounterFormats: [pwgCounterFormat] {
        // Convert format string to a list of pwgCounterFormat
        let stringList: [String] = self.split(separator: "|").map({ String($0) })
        let formatList: [pwgCounterFormat] = stringList.compactMap({ pwgCounterFormat($0) })
        
        // Get prefix from list
        let prefix: pwgCounterFormat = formatList.filter({
            if case .prefix(format: _) = $0 { return true }
            return false
        }).first  ?? .prefix(format: .none)
        
        // Get number format from list
        let number: pwgCounterFormat = formatList.filter({
            if case .digits(format: _) = $0 { return true }
            return false
        }).first  ?? .digits(format: .one)
        
        // Get suffix from list
        let suffix: pwgCounterFormat = formatList.filter({
            if case .suffix(format: _) = $0 { return true }
            return false
        }).first  ?? .suffix(format: .none)
        
        // Return prefix, number or suffix formats
        return [prefix, number, suffix]
    }
}
