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
                // Retry as this should be fine
                if Thread.isMainThread {
                    doWithAccess()
                } else {
                    DispatchQueue.main.async(execute: {
                        doWithAccess()
                    })
                }
        }
    }

    @objc
    func getFileNameFomImageAsset(_ imageAsset: PHAsset?) -> String {
        var fileName = ""
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

            // If no filename…
            if fileName.count == 0 {
                // No filename => Build filename from creation date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
                if let creation = imageAsset?.creationDate {
                    fileName = dateFormatter.string(from: creation)
                }

                // Filename extension required by Piwigo so that it knows how to deal with it
                if imageAsset?.mediaType == .image {
                    // Adopt JPEG photo format by default, will be rechecked
                    fileName = URL(fileURLWithPath: fileName).appendingPathExtension("jpg").lastPathComponent
                } else if imageAsset?.mediaType == .video {
                    // Videos are exported in MP4 format
                    fileName = URL(fileURLWithPath: fileName).appendingPathExtension("mp4").lastPathComponent
                } else if imageAsset?.mediaType == .audio {
                    // Arbitrary extension, not managed yet
                    fileName = URL(fileURLWithPath: fileName).appendingPathExtension("m4a").lastPathComponent
                }
            }
        }

        print("=> filename = \(fileName)")
        return fileName
    }

    private var library: PHPhotoLibrary?
    private var count = 0

    private func requestPhotoLibraryAccess(in viewController: UIViewController?) {
        // Invite user to provide access to photos
        let alert = UIAlertController(title: NSLocalizedString("localAlbums_photosNotAuthorized_title", comment: "No Access"), message: NSLocalizedString("localAlbums_photosNotAuthorized_msg", comment: "tell user to change settings, how"), preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .destructive, handler: { action in
            })

        let prefsAction = UIAlertAction(title: NSLocalizedString("alertOkButton", comment: "OK"), style: .default, handler: { action in
                // Redirect user to Settings app
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.openURL(url)
                }
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(prefsAction)

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        viewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    func showPhotosLibraryAccessRestricted(in viewController: UIViewController?) {
        let alert = UIAlertController(title: NSLocalizedString("localAlbums_photosNiltitle", comment: "Problem Reading Photos"), message: NSLocalizedString("localAlbums_photosNnil_msg", comment: "There is a problem reading your local photo library."), preferredStyle: .alert)

        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { action in
            })

        // Present alert
        alert.addAction(dismissAction)
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        viewController?.present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }
}
