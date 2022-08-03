//
//  PhotosFetch.swift
//  piwigo
//
//  Created by Spencer Baker on 12/16/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 17/04/2020
//

import Foundation
import Photos
import UIKit
import piwigoKit

class PhotosFetch: NSObject {
    
    // Singleton
    static let shared = PhotosFetch()
    
    // MARK: - Photo Library Access
    /// Called before saving photos to the Photo Library or uploading photo of the Library
    @available(iOS 14, *)
    func checkPhotoLibraryAuthorizationStatus(for accessLevel: PHAccessLevel,
                                              for viewController: UIViewController?,
                                              onAccess doWithAccess: @escaping () -> Void,
                                              onDeniedAccess doWithoutAccess: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: accessLevel)
        switch status {
        case .notDetermined:
            // Request authorization to access photos
            PHPhotoLibrary.requestAuthorization(for: accessLevel) { (status) in
                // Created "Photos access" in Settings app for Piwigo, returned user's choice
                switch status {
                    case .restricted:
                        switch accessLevel {
                        case .addOnly:
                            // User wishes to share photos
                            // => Will not allow to save photos in the Photo Library
                            doWithoutAccess()
                        default:
                            // Inform user that he/she cannot access the Photo library
                            if viewController != nil {
                                if Thread.isMainThread {
                                    self.showPhotosLibraryAccessRestricted(in: viewController)
                                } else {
                                    DispatchQueue.main.async(execute: {
                                        self.showPhotosLibraryAccessRestricted(in: viewController)
                                    })
                                }
                            }
                            doWithoutAccess()
                        }
                    case .denied:
                        switch accessLevel {
                        case .addOnly:
                            // User wishes to share photos
                            // => Will not allow to save photos in the Photo Library
                            doWithoutAccess()
                        default:
                            // Invite user to provide access to the Photo library
                            if viewController != nil {
                                if Thread.isMainThread {
                                    self.requestPhotoLibraryAccess(in: viewController)
                                } else {
                                    DispatchQueue.main.async(execute: {
                                        self.requestPhotoLibraryAccess(in: viewController)
                                    })
                                }
                            }
                        }
                    default:
                        // Allowed to read and add photos with limitations or not
                        if Thread.isMainThread {
                            doWithAccess()
                        } else {
                            DispatchQueue.main.async(execute: {
                                doWithAccess()
                            })
                        }
                }
            }
        case .restricted:
            switch accessLevel {
            case .addOnly:
                // User wishes to share photos
                // => Will not allow to save photos in the Photo Library
                doWithoutAccess()
            default:
                // Inform user that he/she cannot access the Photo library
                if viewController != nil {
                    if Thread.isMainThread {
                        showPhotosLibraryAccessRestricted(in: viewController)
                    } else {
                        DispatchQueue.main.async(execute: {
                            self.showPhotosLibraryAccessRestricted(in: viewController)
                        })
                    }
                }
                doWithoutAccess()
            }
        case .denied:
            switch accessLevel {
            case .addOnly:
                // User wishes to share photos
                // => Will not allow to save photos in the Photo Library
                doWithoutAccess()
            default:
                // Invite user to provide access to the Photo library
                if viewController != nil {
                    if Thread.isMainThread {
                        requestPhotoLibraryAccess(in: viewController)
                    } else {
                        DispatchQueue.main.async(execute: {
                            self.requestPhotoLibraryAccess(in: viewController)
                        })
                    }
                }
            }
        case .limited, .authorized:
            // Allowed to read and add photos with limitations or not
            if Thread.isMainThread {
                doWithAccess()
            } else {
                DispatchQueue.main.async(execute: {
                    doWithAccess()
                })
            }
        @unknown default:
            print("unknown Photo Library authorization status")
        }
    }

    /// Used up to iOS 13
    func checkPhotoLibraryAccessForViewController(_ viewController: UIViewController?,
                                                  onAuthorizedAccess doWithAccess: @escaping () -> Void,
                                                  onDeniedAccess doWithoutAccess: @escaping () -> Void) {
        
        // Check autorisation to access Photo Library
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
            case .notDetermined:
                // Request authorization to access photos
                PHPhotoLibrary.requestAuthorization({ status in
                    // Create "Photos access" in Settings app for Piwigo, return user's choice
                    switch status {
                        case .restricted:
                            // Inform user that he/she cannot access the Photo library
                            if viewController != nil {
                                if Thread.isMainThread {
                                    self.showPhotosLibraryAccessRestricted(in: viewController)
                                } else {
                                    DispatchQueue.main.async(execute: {
                                        self.showPhotosLibraryAccessRestricted(in: viewController)
                                    })
                                }
                            }
                            // Exceute next steps
                            doWithoutAccess()
                        case .denied:
                            // Invite user to provide access to the Photo library
                            if viewController != nil {
                                if Thread.isMainThread {
                                    self.requestPhotoLibraryAccess(in: viewController)
                                } else {
                                    DispatchQueue.main.async(execute: {
                                        self.requestPhotoLibraryAccess(in: viewController)
                                    })
                                }
                            }
                            // Exceute next steps
                            doWithoutAccess()
                        default:
                            // Retry as this should be fine
                            if Thread.isMainThread {
                                doWithAccess()
                            } else {
                                DispatchQueue.main.async(execute: {
                                    doWithAccess()
                                })
                            }
                    }
                })
            case .restricted:
                // Inform user that he/she cannot access the Photo library
                if viewController != nil {
                    if Thread.isMainThread {
                        showPhotosLibraryAccessRestricted(in: viewController)
                    } else {
                        DispatchQueue.main.async(execute: {
                            self.showPhotosLibraryAccessRestricted(in: viewController)
                        })
                    }
                }
                // Exceute next steps
                doWithoutAccess()
            case .denied:
                // Invite user to provide access to the Photo library
                if viewController != nil {
                    if Thread.isMainThread {
                        requestPhotoLibraryAccess(in: viewController)
                    } else {
                        DispatchQueue.main.async(execute: {
                            self.requestPhotoLibraryAccess(in: viewController)
                        })
                    }
                }
                // Exceute next steps
                doWithoutAccess()
            default:
                // Should be fine
                if Thread.isMainThread {
                    doWithAccess()
                } else {
                    DispatchQueue.main.async(execute: {
                        doWithAccess()
                    })
                }
        }
    }

    func requestPhotoLibraryAccess(in viewController: UIViewController?) {
        // Invite user to provide access to photos
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .destructive, handler: { action in })

        let prefsAction = UIAlertAction(title: NSLocalizedString("alertOkButton", comment: "OK"), style: .default, handler: { action in
                // Redirect user to Settings app
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.openURL(url)
                }
            })

        // Present alert
        let title = NSLocalizedString("localAlbums_photosNotAuthorized_title", comment: "No Access")
        let message = NSLocalizedString("localAlbums_photosNotAuthorized_msg", comment: "tell user to change settings, how")
        viewController?.presentPiwigoAlert(withTitle: title, message: message,
                                actions: [cancelAction, prefsAction])
    }

    func showPhotosLibraryAccessRestricted(in viewController: UIViewController?) {
        viewController?.dismissPiwigoError(withTitle: NSLocalizedString("localAlbums_photosNiltitle", comment: "Problem Reading Photos"), message: NSLocalizedString("localAlbums_photosNnil_msg", comment: "There is a problem reading your local photo library."), completion: {})
    }
}
