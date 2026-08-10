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
        // Adopt the metadata setting which used to govern the apps the user actually shares with.
        /// The built-in social activity types have not been vended since iOS 11, so every
        /// third-party app fell into the 'other' case: it is the only one worth carrying over.
        /// The choice is now global instead of per-activity, hence a single value for both switches.
        /// Runs only once: the key is removed by the loop below.
        if let sharesMetadataWithOtherApps = UserDefaults.standard.object(forKey: "shareMetadataTypeOther") as? Bool,
           UserDefaults.standard.object(forKey: "shareKeepsLocation") == nil,
           UserDefaults.standard.object(forKey: "shareKeepsContactInfo") == nil {
            self.shareKeepsLocation = sharesMetadataWithOtherApps
            self.shareKeepsContactInfo = sharesMetadataWithOtherApps
        }

        // Per-activity share metadata settings, replaced by the options which the user
        // now chooses before each share (see ShareOptionsViewController).
        let deprecatedShareMetadataKeys = ["shareMetadataTypeAirDrop",
                                           "shareMetadataTypeAssignToContact",
                                           "shareMetadataTypeCopyToPasteboard",
                                           "shareMetadataTypeMail",
                                           "shareMetadataTypeMessage",
                                           "shareMetadataTypeSaveToCameraRoll",
                                           "shareMetadataTypeOther",
                                           "shareMetadataTypePostToFacebook",
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

    /// - Options chosen the last time images were shared
    ///   The location is dropped by default, the author's name and contact info are kept:
    ///   Piwigo users are most often the photographers of the images they share.
    @UserDefault("shareFormat", defaultValue: pwgShareFormat.original.rawValue)
    var shareFormat: Int16

    @UserDefault("shareSize", defaultValue: pwgShareSize.original.rawValue)
    var shareSize: Int16

    @UserDefault("shareKeepsLocation", defaultValue: false)
    var shareKeepsLocation: Bool

    @UserDefault("shareKeepsContactInfo", defaultValue: true)
    var shareKeepsContactInfo: Bool


    // MARK: - Vars in UserDefaults / App Group
    // Image variables stored in UserDefaults / App Group
    /// - None


    // MARK: - Constants and Vars in Memory
    // Constants
    // Bug introduced on 6 September 2024 (commit 18e427379a8132575a72ef053fe7d26090e09525)
    let dateCommit18e4273 = ISO8601DateFormatter().date(from: "2024-09-06T00:00:00Z")!
    let dateOfFirstOptImageV323 = {
        if AppVars.shared.dateOfFirstOptImageV323 == Date.distantFuture.timeIntervalSinceReferenceDate {
            AppVars.shared.dateOfFirstOptImageV323 = Date.timeIntervalSinceReferenceDate
        }
        return Date(timeIntervalSinceReferenceDate: AppVars.shared.dateOfFirstOptImageV323)
    }()
    
    // Image variables kept in memory
    /// - None
}
