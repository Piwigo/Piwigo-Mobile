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

@objc
class PhotosFetch: NSObject {
    
    // Singleton
    @objc static var instance: PhotosFetch = PhotosFetch()

    @objc
    class func sharedInstance() -> PhotosFetch {
        // `dispatch_once()` call was converted to a static variable initializer
        return instance
    }
    
    // MARK: - Photo Library Access
    /// Called before saving photos to the Photo Library or uploading photo of the Library
    @available(iOS 14, *)
    @objc
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
    @objc
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


    // MARK: - File name from PHAsset
    @objc
    func getFileNameFomImageAsset(_ imageAsset: PHAsset?) -> String {
        var fileName = ""
        
        // Asset resource available?
        if imageAsset != nil {
            // Get file name from image asset
            var resources: [PHAssetResource]? = nil
            if let imageAsset = imageAsset {
                resources = PHAssetResource.assetResources(for: imageAsset)
            }
            // Shared assets may not return resources
            if (resources?.count ?? 0) > 0 {
                for resource in resources ?? [] {
                    if resource.type == .adjustmentData {
                        continue
                    }
                    fileName = resource.originalFilename
                    if (resource.type == .photo) || (resource.type == .video) || (resource.type == .audio) {
                        // We preferably select the original filename
                        break
                    }
                }
            }
        }
        
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        var utf8mb3Filename = NetworkUtilities.utf8mb3String(from: fileName) ?? ""

        // If encodedFileName is empty, build one from the current date
        if utf8mb3Filename.count == 0 {
            // No filename => Build filename from creation date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            if let creation = imageAsset?.creationDate {
                utf8mb3Filename = dateFormatter.string(from: creation)
            } else {
                utf8mb3Filename = dateFormatter.string(from: Date())
            }

            // Filename extension required by Piwigo so that it knows how to deal with it
            if imageAsset?.mediaType == .image {
                // Adopt JPEG photo format by default, will be rechecked
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("jpg").lastPathComponent
            } else if imageAsset?.mediaType == .video {
                // Videos are exported in MP4 format
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("mp4").lastPathComponent
            } else if imageAsset?.mediaType == .audio {
                // Arbitrary extension, not managed yet
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("m4a").lastPathComponent
            }
        }

//        print("=> adopted filename = \(utf8mb3Filename)")
        return utf8mb3Filename
    }
}
