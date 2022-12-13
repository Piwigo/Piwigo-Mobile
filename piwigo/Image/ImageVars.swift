//
//  ImageVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class ImageVars: NSObject {
    
    // Singleton
    @objc static let shared = ImageVars()
    
    // Remove deprecated stored objects if needed
//    override init() {
//        // Deprecated data?
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
//    }

    // MARK: - Vars in UserDefaults / Standard
    // Images variables stored in UserDefaults / Standard
    /// - Size of the image file presented in preview mode on the main screen (i.e. full screen mode)
    @UserDefault("defaultImagePreviewSize", defaultValue: ImageUtilities.optimumImageSizeForDevice().rawValue)
    @objc var defaultImagePreviewSize: Int16

    /// - Share image by AirDrop with metadata by default
    @UserDefault("shareMetadataTypeAirDrop", defaultValue: true)
    @objc var shareMetadataTypeAirDrop: Bool

    /// - Strip metadata when assigning image to Contact by default
    @UserDefault("shareMetadataTypeAssignToContact", defaultValue: false)
    @objc var shareMetadataTypeAssignToContact: Bool

    /// - Strip metadata when sharing image with the clipboard by default
    @UserDefault("shareMetadataTypeCopyToPasteboard", defaultValue: false)
    @objc var shareMetadataTypeCopyToPasteboard: Bool

    /// - Share image by email with metadata by default
    @UserDefault("shareMetadataTypeMail", defaultValue: true)
    @objc var shareMetadataTypeMail: Bool

    /// - Share image with metadata when sharing with Messages by default
    @UserDefault("shareMetadataTypeMessage", defaultValue: true)
    @objc var shareMetadataTypeMessage: Bool

    /// - Strip metadata when sharing image with Facebook by default
    @UserDefault("shareMetadataTypePostToFacebook", defaultValue: false)
    @objc var shareMetadataTypePostToFacebook: Bool

    /// - Strip metadata when sharing image with Messenger by default
    @UserDefault("shareMetadataTypeMessenger", defaultValue: false)
    @objc var shareMetadataTypeMessenger: Bool
    
    /// - Strip metadata when sharing image with Flicker by default
    @UserDefault("shareMetadataTypePostToFlickr", defaultValue: false)
    @objc var shareMetadataTypePostToFlickr: Bool
    
    /// - Strip metadata when posting image on Instagram by default
    @UserDefault("shareMetadataTypePostInstagram", defaultValue: true)
    @objc var shareMetadataTypePostInstagram: Bool
    
    /// - Share image with metadata when sharing with Signal by default
    @UserDefault("shareMetadataTypePostToSignal", defaultValue: true)
    @objc var shareMetadataTypePostToSignal: Bool
    
    /// - Strip metadata when posting image on Snapchat by default
    @UserDefault("shareMetadataTypePostToSnapchat", defaultValue: false)
    @objc var shareMetadataTypePostToSnapchat: Bool
    
    /// - Strip metadata when posting image on Tencent Weibo by default
    @UserDefault("shareMetadataTypePostToTencentWeibo", defaultValue: false)
    @objc var shareMetadataTypePostToTencentWeibo: Bool
    
    /// - Strip metadata when posting image on Twitter by default
    @UserDefault("shareMetadataTypePostToTwitter", defaultValue: false)
    @objc var shareMetadataTypePostToTwitter: Bool
    
    /// - Strip metadata when posting image on Vimeo by default
    @UserDefault("shareMetadataTypePostToVimeo", defaultValue: false)
    @objc var shareMetadataTypePostToVimeo: Bool
    
    /// - Strip metadata when posting image on Weibo by default
    @UserDefault("shareMetadataTypePostToWeibo", defaultValue: false)
    @objc var shareMetadataTypePostToWeibo: Bool
    
    /// - Strip metadata when sharing image with Whatsapp by default
    @UserDefault("shareMetadataTypePostToWhatsApp", defaultValue: false)
    @objc var shareMetadataTypePostToWhatsApp: Bool
    
    /// - Keep metadata when saving image in camera roll by default
    @UserDefault("shareMetadataTypeSaveToCameraRoll", defaultValue: true)
    @objc var shareMetadataTypeSaveToCameraRoll: Bool
    
    /// - Strip metadata when sharing image with unknown app by default
    @UserDefault("shareMetadataTypeOther", defaultValue: false)
    @objc var shareMetadataTypeOther: Bool

    
    // MARK: - Vars in UserDefaults / App Group
    // Image variables stored in UserDefaults / App Group
    /// - None


    // MARK: - Vars in Memory
    // Image variables kept in memory
    /// - None
}
