//
//  LoginUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

enum pwgLoginContext {
    case nonTrustedCertificate
    case nonSecuredAccess
    case incorrectURL
}

class LoginUtilities: NSObject {
    
    // MARK: - Login Business
    static func checkAvailableSizes() {
        // Check that the actual default album thumbnail size is available
        // and select the next available size in case of unavailability
        switch pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) {
        case .xxSmall:
            if !NetworkVars.hasXXSmallSizeImages {
                // Look for next available larger size
                if NetworkVars.hasXSmallSizeImages {
                    AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.xSmall.rawValue
                } else if NetworkVars.hasSmallSizeImages {
                    AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.small.rawValue
                } else {
                    AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.medium.rawValue
                }
            }
        case .xSmall:
            if !NetworkVars.hasXSmallSizeImages {
                // Look for next available larger size
                if NetworkVars.hasSmallSizeImages {
                    AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.small.rawValue
                } else {
                    AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.medium.rawValue
                }
            }
        case .small:
            if !NetworkVars.hasSmallSizeImages {
                // Select next available larger size
                AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .large:
            if !NetworkVars.hasLargeSizeImages {
                AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .xLarge:
            if !NetworkVars.hasXLargeSizeImages {
                AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .xxLarge:
            if !NetworkVars.hasXXLargeSizeImages {
                AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .square, .thumb, .medium, .fullRes:
            // Should always be available
            break
        default:
            AlbumVars.shared.defaultAlbumThumbnailSize = pwgImageSize.medium.rawValue
        }
        
        // Check that the actual default image thumbnail size is available
        // and select the next available size in case of unavailability
        switch pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) {
        case .xxSmall:
            if !NetworkVars.hasXXSmallSizeImages {
                // Look for next available larger size
                if NetworkVars.hasXSmallSizeImages {
                    AlbumVars.shared.defaultThumbnailSize = pwgImageSize.xSmall.rawValue
                } else if NetworkVars.hasSmallSizeImages {
                    AlbumVars.shared.defaultThumbnailSize = pwgImageSize.small.rawValue
                } else {
                    AlbumVars.shared.defaultThumbnailSize = pwgImageSize.medium.rawValue
                }
            }
        case .xSmall:
            if !NetworkVars.hasXSmallSizeImages {
                // Look for next available larger size
                if NetworkVars.hasSmallSizeImages {
                    AlbumVars.shared.defaultThumbnailSize = pwgImageSize.small.rawValue
                } else {
                    AlbumVars.shared.defaultThumbnailSize = pwgImageSize.medium.rawValue
                }
            }
        case .small:
            if !NetworkVars.hasSmallSizeImages {
                // Select next available larger size
                AlbumVars.shared.defaultThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .large:
            if !NetworkVars.hasLargeSizeImages {
                AlbumVars.shared.defaultThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .xLarge:
            if !NetworkVars.hasXLargeSizeImages {
                AlbumVars.shared.defaultThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .xxLarge:
            if !NetworkVars.hasXXLargeSizeImages {
                AlbumVars.shared.defaultThumbnailSize = pwgImageSize.medium.rawValue
            }
        case .square, .thumb, .medium, .fullRes:
            // Should always be available
            break
        default:
            AlbumVars.shared.defaultThumbnailSize = pwgImageSize.medium.rawValue
        }

        // Calculate number of thumbnails per row for that selection
        let minNberOfImages = AlbumUtilities.imagesPerRowInPortrait(forMaxWidth: (pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb).minPoints)

        // Make sure that default number fits inside selected range
        AlbumVars.shared.thumbnailsPerRowInPortrait = max(AlbumVars.shared.thumbnailsPerRowInPortrait, minNberOfImages);
        AlbumVars.shared.thumbnailsPerRowInPortrait = min(AlbumVars.shared.thumbnailsPerRowInPortrait, 2*minNberOfImages);

        // Check that the actual default image preview size is still available
        // and select the next available size in case of unavailability
        switch pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) {
        case .xxSmall:
            if !NetworkVars.hasXXSmallSizeImages {
                // Look for next available larger size
                if NetworkVars.hasXSmallSizeImages {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.xSmall.rawValue
                } else if NetworkVars.hasSmallSizeImages {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.small.rawValue
                } else {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.medium.rawValue
                }
            }
        case .xSmall:
            if !NetworkVars.hasXSmallSizeImages {
                // Look for next available larger size
                if NetworkVars.hasSmallSizeImages {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.small.rawValue
                } else {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.medium.rawValue
                }
            }
        case .small:
            if !NetworkVars.hasSmallSizeImages {
                // Select next available larger size
                ImageVars.shared.defaultImagePreviewSize = pwgImageSize.medium.rawValue
            }
        case .large:
            if !NetworkVars.hasLargeSizeImages {
                // Look for next available larger size
                if NetworkVars.hasXLargeSizeImages {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.xLarge.rawValue
                } else if NetworkVars.hasXXLargeSizeImages {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.xxLarge.rawValue
                } else {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.fullRes.rawValue
                }
            }
        case .xLarge:
            if !NetworkVars.hasXLargeSizeImages {
                // Look for next available larger size
                if NetworkVars.hasXXLargeSizeImages {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.xxLarge.rawValue
                } else {
                    ImageVars.shared.defaultImagePreviewSize = pwgImageSize.fullRes.rawValue
                }
            }
        case .xxLarge:
            if !NetworkVars.hasXXLargeSizeImages {
                ImageVars.shared.defaultImagePreviewSize = pwgImageSize.fullRes.rawValue
            }
        case .square, .thumb, .medium, .fullRes:
            // Should always be available
            break
        default:
            ImageVars.shared.defaultImagePreviewSize = pwgImageSize.fullRes.rawValue
        }
    }
    
    static func getHttpCredentialsAlert(textFieldDelegate: UITextFieldDelegate?,
                                        username: String, password: String,
                                        cancelAction: @escaping ((UIAlertAction) -> Void),
                                        loginAction: @escaping ((UIAlertAction) -> Void)) -> UIAlertController {
        let alert = UIAlertController(
            title: NSLocalizedString("loginHTTP_title", comment: "HTTP Credentials"),
            message: NSLocalizedString("loginHTTP_message", comment: "HTTP basic authentification is required by the Piwigo server:"),
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

        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        }
        return alert
    }
}
