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
    let firstIPhoneAnnouncementDate: Date = {
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
    
    func updateExample(prefixActions: RenameActionList = UploadVars.shared.prefixFileNameActionList.actions,
                       replaceActions: RenameActionList = UploadVars.shared.replaceFileNameActionList.actions,
                       suffixActions: RenameActionList = UploadVars.shared.suffixFileNameActionList.actions) {
        var renamed = exampleFileName
        renamed.rename(withPrefixActions: prefixActions, replaceActions: replaceActions, suffixActions: suffixActions,
                       date: firstIPhoneAnnouncementDate, counter: UploadVars.shared.startCounterValue)
        text = exampleFileName + "\r" + "⇩" + "\r" + renamed
    }
}
