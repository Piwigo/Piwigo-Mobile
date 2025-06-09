//
//  RenameFileInfoLabel.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

class RenameFileInfoLabel: UILabel {
    
    // Example file name
    let exampleFileName: String = "IMG_0023.HEIC"
    
    // Date when Steve Jobs first announced the iPhone
    let iPhoneAnnouncementDate: Date = {
        var components = DateComponents()
        components.year = 2007
        components.month = 01
        components.day = 9
        components.hour = 9
        components.minute = 41
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: components)!
    }()
    
    func updateExample(prefix: Bool, prefixActions: RenameActionList,
                       replace: Bool, replaceActions: RenameActionList,
                       suffix: Bool, suffixActions: RenameActionList,
                       changeCase: Bool, caseOfExtension: FileExtCase,
                       categoryId: Int32, counter: Int64) {
        var fileName = exampleFileName
        fileName.renameFile(prefixActions: prefix ? prefixActions : [],
                            replaceActions: replace ? replaceActions : [],
                            suffixActions: suffix ? suffixActions : [],
                            caseOfExtension: changeCase ? caseOfExtension : .keep,
                            albumID: categoryId, date: iPhoneAnnouncementDate, counter: counter)
        text = exampleFileName + "\r" + "⇩" + "\r" + fileName
    }
}
