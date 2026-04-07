//
//  LoginUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

enum pwgLoginContext {
    case nonTrustedCertificate
    case nonSecuredAccess
    case incorrectURL
}

struct LoginUtilities
{
    // MARK: - Login Business
    @MainActor
    static func checkAvailableSizes(forScale scale: CGFloat) {
        // Check that default sizes were initialised
        if AlbumVars.shared.defaultAlbumThumbnailSize == -1 {
            AlbumVars.shared.defaultAlbumThumbnailSize = AlbumUtilities.optimumAlbumThumbnailSizeForDevice().rawValue
        }
        if AlbumVars.shared.defaultThumbnailSize == -1 {
            AlbumVars.shared.defaultThumbnailSize = AlbumUtilities.optimumThumbnailSizeForDevice().rawValue
        }
        if ImageVars.shared.defaultImagePreviewSize == -1 {
            ImageVars.shared.defaultImagePreviewSize = ImageUtilities.optimumImageSizeForDevice().rawValue
        }
        
        // Check that the actual default album thumbnail size is available
        // and select the next available size in case of unavailability
        let albumThumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .thumb
        AlbumVars.shared.defaultAlbumThumbnailSize = getAvailableSize(near: albumThumbSize).rawValue
        debugPrint("Album thumbnail size: \(getAvailableSize(near: albumThumbSize))")
        
        // Check that the actual default image thumbnail size is available
        // and select the next available size in case of unavailability
        let imageThumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        AlbumVars.shared.defaultThumbnailSize = getAvailableSize(near: imageThumbSize).rawValue
        debugPrint("Image thumbnail size: \(getAvailableSize(near: imageThumbSize))")
        
        // Calculate number of thumbnails per row for that selection
        let albumThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        let albumThumbnailMaxWidth = albumThumbnailSize.minPoints(forScale: scale) * scale  // i.e. 1 screen point = 1 image pixel
        let minNberOfImages: Int = AlbumUtilities.imagesPerRowInPortrait(forMaxWidth: albumThumbnailMaxWidth)
        
        // Make sure that default number fits inside selected range
        AlbumVars.shared.thumbnailsPerRowInPortrait = max(AlbumVars.shared.thumbnailsPerRowInPortrait, minNberOfImages);
        AlbumVars.shared.thumbnailsPerRowInPortrait = min(AlbumVars.shared.thumbnailsPerRowInPortrait, 2*minNberOfImages);
        
        // Check that the actual default image preview size is still available
        // and select the next available size in case of unavailability
        let imagePreviewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .fullRes
        ImageVars.shared.defaultImagePreviewSize = getAvailableSize(near: imagePreviewSize).rawValue
        debugPrint("Image preview size: \(getAvailableSize(near: imagePreviewSize))")
    }
    
    @MainActor
    private static func getAvailableSize(near wantedSize: pwgImageSize) -> pwgImageSize
    {
        // Select the next greater available size in case of unavailability
        // knowing that the fullRes file might not be available (treated case per case)
        var greaterSizes = pwgImageSize.allCases
        greaterSizes.removeAll(where: { $0 < wantedSize })
        for greaterSize in greaterSizes {
            if greaterSize.isAvailable {
                return greaterSize
            }
        }
        return .fullRes
    }
    
    @MainActor
    static func getHttpCredentialsAlert(textFieldDelegate: (any UITextFieldDelegate)?,
                                        username: String, password: String,
                                        cancelAction: @escaping ((UIAlertAction) -> Void),
                                        loginAction: @escaping ((UIAlertAction) -> Void)) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("loginHTTP_title", comment: "HTTP Credentials"),
            message: NSLocalizedString("loginHTTP_message", comment: "Piwigo server requires HTTP basic access authentication…"),
            preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("loginHTTPuser_placeholder", comment: "username")
            textField.text = (username.count > 0) ? username : ""
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.returnKeyType = .continue
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.delegate = textFieldDelegate
        })
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("loginHTTPpwd_placeholder", comment: "password")
            textField.text = (password.count > 0) ? password : ""
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.isSecureTextEntry = true
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.returnKeyType = .continue
            textField.delegate = textFieldDelegate
        })
        
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: cancelAction)
        alert.addAction(cancelAction)
        
        let loginAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
            style: .default, handler: loginAction)
        alert.addAction(loginAction)
        
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        return alert
    }
}
