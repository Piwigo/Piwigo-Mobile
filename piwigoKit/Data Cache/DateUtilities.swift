//
//  DateUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 29/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

public class DateUtilities: NSObject {
    
    /* Timeintervals used for managing image dates
    let dateFormatterISO = ISO8601DateFormatter()
    let refDate = dateFormatterISO.date(from: "1900-01-01T00:00:00Z")       // 00:00:00 UTC on 1 January 1900
    let refDateInterval = refDate?.timeIntervalSinceReferenceDate           // => -3187296000
    let weekAfter = dateFormatterISO.date(from: "1900-01-08T00:00:00Z")     // 00:00:00 UTC on 8 January 1900
    let weekAfterInterval = weekAfter?.timeIntervalSinceReferenceDate       // => -3186691200
     */
    public static let refDateInterval = TimeInterval(-3187296000)
    public static let weekAfterInterval = TimeInterval(-3187209600)

    public static let format = "yyyy-MM-dd HH:mm:ss"
    
    public static var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter
    }()
    
    static func timeInterval(from dateStr: String?) -> TimeInterval? {
        // Convert string to date
        guard let pwgDate = dateFormatter.date(from: dateStr ?? "")
        else { return nil }
        
        // Return corresponding time interval since 00:00:00 UTC on 1 January 2001
        // if the converted date is after 00:00:00 UTC on 8 January 1900
        let pwgInterval = pwgDate.timeIntervalSinceReferenceDate
        if pwgInterval < weekAfterInterval {
            return nil
        }
        return pwgInterval
    }
}
