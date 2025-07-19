//
//  DateUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 29/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

public class DateUtilities: NSObject {
    
    // Unknown date is 00:00:00 UTC on 1 January 1900
    public static let unknownDate = ISO8601DateFormatter().date(from: "1900-01-01T00:00:00Z")!
    public static let unknownDateInterval = unknownDate.timeIntervalSinceReferenceDate
    
    // A week after unknown date is 00:00:00 UTC on 8 January 1900
    public static let weekAfter = ISO8601DateFormatter().date(from: "1900-01-08T00:00:00Z")!
    public static let weekAfterInterval = weekAfter.timeIntervalSinceReferenceDate
    
    // Dates are provided by Piwigo servers as strings in the local time.
    // We store each date as a TimeInterval since 00:00:00 UTC on 1 January 2001.
    public static let pwgDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")!
        return formatter
    }()
    
    // Logs dates are provided with UTC time
    public static let logsDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.sss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")!
        return formatter
    }()
    
    
    // Return corresponding time interval since 00:00:00 UTC on 1 January 2001
    // if the converted date is after 00:00:00 UTC on 8 January 1900
    static func timeInterval(from dateStr: String?) -> TimeInterval? {
        // Convert Piwigo string to date
        // Since Xcode 16.4, the date format "forgets" the time components of the date format.
        // pwgDateFormatter.dateFormat = Optional(\"yyyy-MM-dd HH:mm:ss\") becomes Optional(\"yyyy-MM-dd\").
        // Console reports:
        // _attributes = (__NSDictionaryM *) 4 key/value pairs
        //      [0]    (null)    "locale" : 0x0000000107e16c00
        //      [1]    (null)    "timeZone" : 0x000000011cd15580
        //      [2]    (null)    "formatterBehavior" : Int64(1040)
        //      [3]    (null)    "dateFormat" : (no summary)
        // instead of:
        // _attributes = (__NSDictionaryM *) 4 key/value pairs
        //      [0]    (null)    "locale" : 0x0000000107e16c00
        //      [1]    (null)    "timeZone" : 0x000000011cd15580
        //      [2]    (null)    "formatterBehavior" : Int64(1040)
        //      [3]    (null)    "dateFormat" : "yyyy-MM-dd HH:mm:ss"
        // So we reset dateFormat below.
        pwgDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let pwgDate = pwgDateFormatter.date(from: dateStr ?? "")
        else { return nil }
        
        let pwgInterval = pwgDate.timeIntervalSinceReferenceDate
        if pwgInterval < weekAfterInterval {
            return nil
        }
        return pwgInterval
    }
    
    // Return Piwigo date string with UTC time
    public static func string(from timeInterval: TimeInterval?) -> String {
        // Return unknown date if nil
        guard let timeInterval = timeInterval
        else { return pwgDateFormatter.string(from: unknownDate) }
        
        let date = Date(timeIntervalSinceReferenceDate: timeInterval)
        return pwgDateFormatter.string(from: date)
    }
    
    // Return date formatter in UTC time
    public static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(abbreviation: "UTC")!
        return formatter
    }
    
    // Return date interval formatter in UTC time
    public static func dateIntervalFormatter() -> DateIntervalFormatter {
        let formatter = DateIntervalFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone(abbreviation: "UTC")!
        return formatter
    }
}
