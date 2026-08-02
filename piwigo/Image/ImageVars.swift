//
//  ImageVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists image settings.

import Foundation
import PwgKit

// Mark ImageVars as Sendable since Apple documents UserDefaults as thread-safe
final class ImageVars: @unchecked Sendable {
    
    // Singleton
    static let shared = ImageVars()

    // Remove deprecated stored objects if needed
    init() {
        // Share metadata settings of activity types which iOS no longer proposes:
        // the built-in social integration was removed in iOS 11 and the apps which
        // replaced it are handled by the 'shareMetadataTypeOther' setting.
        let deprecatedShareMetadataKeys = ["shareMetadataTypePostToFacebook",
                                           "shareMetadataTypeMessenger",
                                           "shareMetadataTypePostToFlickr",
                                           "shareMetadataTypePostInstagram",
                                           "shareMetadataTypePostToSignal",
                                           "shareMetadataTypePostToSnapchat",
                                           "shareMetadataTypePostToTencentWeibo",
                                           "shareMetadataTypePostToTwitter",
                                           "shareMetadataTypePostToVimeo",
                                           "shareMetadataTypePostToWeibo",
                                           "shareMetadataTypePostToWhatsApp"]
        for key in deprecatedShareMetadataKeys {
            if UserDefaults.standard.object(forKey: key) != nil {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Vars in UserDefaults / Standard
    // Images variables stored in UserDefaults / Standard
    /// - Size of the image file presented in preview mode on the main screen (i.e. full screen mode)
    @UserDefault("defaultImagePreviewSize", defaultValue: -1)
    var defaultImagePreviewSize: Int16

    /// - Share image by AirDrop with metadata by default
    @UserDefault("shareMetadataTypeAirDrop", defaultValue: true)
    var shareMetadataTypeAirDrop: Bool

    /// - Strip metadata when assigning image to Contact by default
    @UserDefault("shareMetadataTypeAssignToContact", defaultValue: false)
    var shareMetadataTypeAssignToContact: Bool

    /// - Strip metadata when sharing image with the clipboard by default
    @UserDefault("shareMetadataTypeCopyToPasteboard", defaultValue: false)
    var shareMetadataTypeCopyToPasteboard: Bool

    /// - Share image by email with metadata by default
    @UserDefault("shareMetadataTypeMail", defaultValue: true)
    var shareMetadataTypeMail: Bool

    /// - Share image with metadata when sharing with Messages by default
    @UserDefault("shareMetadataTypeMessage", defaultValue: true)
    var shareMetadataTypeMessage: Bool

    /// - Keep metadata when saving image in camera roll by default
    @UserDefault("shareMetadataTypeSaveToCameraRoll", defaultValue: true)
    var shareMetadataTypeSaveToCameraRoll: Bool
    
    /// - Strip metadata when sharing image with unknown app by default
    @UserDefault("shareMetadataTypeOther", defaultValue: false)
    var shareMetadataTypeOther: Bool

    
    // MARK: - Vars in UserDefaults / App Group
    // Image variables stored in UserDefaults / App Group
    /// - None


    // MARK: - Constants and Vars in Memory
    // Constants
    // Bug introduced on 6 September 2024 (commit 18e427379a8132575a72ef053fe7d26090e09525)
    let dateCommit18e4273 = ISO8601DateFormatter().date(from: "2024-09-06T00:00:00Z")!
    let dateOfFirstOptImageV323 = {
        if AppVars.shared.dateOfFirstOptImageV323 == Date.distantFuture.timeIntervalSinceReferenceDate {
            AppVars.shared.dateOfFirstOptImageV323 = Date().timeIntervalSinceReferenceDate
        }
        return Date(timeIntervalSinceReferenceDate: AppVars.shared.dateOfFirstOptImageV323)
    }()
    
    // Image variables kept in memory
    /// - None
}
