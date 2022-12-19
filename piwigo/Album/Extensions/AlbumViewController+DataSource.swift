//
//  AlbumViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/07/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

extension AlbumViewController
{
    // MARK: - Login / Relogin
    func reloginAndReloadAlbumData(completion: @escaping () -> Void) {
        /// - Pause upload operations
        /// - Perform relogin
        /// - Reload album data
        /// - Resume upload operations in background queue
        ///   and update badge, upload button of album navigator
        UploadManager.shared.isPaused = true
        
        // Request server methods
        LoginUtilities.requestServerMethods { [unowned self] in
            // Known methods, pursue logging in…
            performLogin() {
                completion()
            }
        } didRejectCertificate: { [unowned self] error in
            requestCertificateApproval(afterError: error) {
                completion()
            }
        } didFailHTTPauthentication: { [unowned self] error in
            showError(error)
        } didFailSecureConnection: { [unowned self] error in
            showError(error)
        } failure: { [unowned self] error in
            showError(error)
        }
    }
    
    func requestCertificateApproval(afterError error: Error?,
                                    completion: @escaping () -> Void) {
        DispatchQueue.main.async { [unowned self] in
            let title = NSLocalizedString("loginCertFailed_title", comment: "Connection Not Private")
            let message = "\(NSLocalizedString("loginCertFailed_message", comment: "Piwigo warns you when a website has a certificate that is not valid. Do you still want to accept this certificate?"))\r\r\(NetworkVars.certificateInformation)"
            let cancelAction = UIAlertAction(
                title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                style: .cancel, handler: { [self] action in
                    // Should forget certificate
                    NetworkVars.didApproveCertificate = false
                    // Report error
                    showError(error)
                })
            let acceptAction = UIAlertAction(
                title: NSLocalizedString("alertOkButton", comment: "OK"),
                style: .default, handler: { [self] action in
                    // Will accept certificate
                    NetworkVars.didApproveCertificate = true
                    // Try logging in with approved certificate
                    performLogin {
                        completion()
                    }
                })
            presentPiwigoAlert(withTitle: title, message: message, actions: [cancelAction, acceptAction])
        }
    }
    
    func performLogin(completion: @escaping () -> Void) {
        // Did the user cancel communication?
        if NetworkVars.userCancelledCommunication {
            showError(nil)
            return
        }
        
        // Perform login if username exists
        let username = NetworkVars.username
        if username.isEmpty {
            // Check Piwigo version, get token, available sizes, etc.
            getCommunityStatus() {
                completion()
            }
        } else {
            // Perform login
            let password = KeychainUtilities.password(forService: NetworkVars.serverPath, account: username)
            LoginUtilities.sessionLogin(withUsername: NetworkVars.username, password: password) { [self] in
                // Session now opened
                // First determine user rights if Community extension installed
                getCommunityStatus() {
                    completion()
                }
            } failure: { [unowned self] error in
                // Login request failed
                showError(NetworkVars.userCancelledCommunication ? nil : error)
            }
        }
    }
    
    func getCommunityStatus(completion: @escaping () -> Void) {
        // Did the user cancel communication?
        if NetworkVars.userCancelledCommunication {
            showError(nil)
            return
        }
        
        if NetworkVars.usesCommunityPluginV29 {
            // Community extension installed
            LoginUtilities.communityGetStatus { [unowned self] in
                // Check Piwigo version, get token, available sizes, etc.
                getSessionStatus() {
                    completion()
                }
            } failure: { [unowned self] error in
                // Inform user that server failed to retrieve Community parameters
                showError(NetworkVars.userCancelledCommunication ? nil : error)
            }
        } else {
            // Community extension not installed
            // Check Piwigo version, get token, available sizes, etc.
            getSessionStatus() {
                completion()
            }
        }
        
    }
    
    func getSessionStatus(completion: @escaping () -> Void) {
        // Did the user cancel communication?
        if NetworkVars.userCancelledCommunication {
            showError(nil)
            return
        }
        
        LoginUtilities.sessionGetStatus { [self] in
            DispatchQueue.main.async { [unowned self] in
                print("••> Reload album and image data…")
                fetchAlbumsAndImages {
                    completion()
                }
            }
        } failure: { [self]  error in
            showError(error)
        }
    }
    
    @objc func cancelLoggingIn() {
        // Propagate user's request
        NetworkVars.userCancelledCommunication = true
        PwgSession.shared.dataSession.getAllTasks(completionHandler: { tasks in
            tasks.forEach { task in
                task.cancel()
            }
        })
        NetworkVarsObjc.sessionManager!.tasks.forEach { task in
            task.cancel()
        }
        
        // Update login HUD
        navigationController?.showPiwigoHUD(
            withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
            detail: NSLocalizedString("internetCancellingConnection_button", comment: "Cancelling Connection…"),
            buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
            buttonTarget: self, buttonSelector: #selector(cancelLoggingIn),
            inMode: .indeterminate)
    }
    
    private func showError(_ error: Error?) {
        DispatchQueue.main.async { [unowned self] in
            if error == nil {
                navigationController?.showPiwigoHUD(
                    withTitle: NSLocalizedString("internetCancelledConnection_title", comment: "Connection Cancelled"),
                    detail: " ",
                    buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                    buttonTarget: self, buttonSelector: #selector(hideLoading),
                    inMode: .text)
            } else {
                var detail = error?.localizedDescription ?? ""
                if detail.isEmpty {
                    detail = String(format: "%ld", (error as NSError?)?.code ?? 0)
                }
                navigationController?.showPiwigoHUD(
                    withTitle: NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error"),
                    detail: detail,
                    buttonTitle: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                    buttonTarget: self, buttonSelector: #selector(hideLoading),
                    inMode: .text)
            }
        }
    }
    
    @objc func hideLoading() {
        // Reinitialise flag
        NetworkVars.userCancelledCommunication = false
        
        // Hide HUD
        navigationController?.hidePiwigoHUD() {
            // Return to login view
            ClearCache.closeSessionAndClearCache { }
        }
    }
    
    
    // MARK: - Album and Image Data
    func fetchAlbumsAndImages(completion: @escaping () -> Void) {
        // Fetch albums and images
        if categoryId < 0 {
            // Use the AlbumProvider to create the album data. On completion,
            // handle general UI updates and error alerts on the main queue.
            DispatchQueue.global(qos: .userInteractive).async { [self] in
                // Remember which images belong to this album
                let oldImageIds = Set(albumData?.images?.compactMap({$0.pwgID}) ?? [])
                // The number of images is unknown when a smart album is created.
                // Use the ImageProvider to fetch image data. On completion,
                // handle general UI updates and error alerts on the main queue.
                let perPage = AlbumUtilities.numberOfImagesToDownloadPerPage()
                self.fetchImages(ofAlbumWithId: self.categoryId, imageIds: oldImageIds,
                                 fromPage: 0, toPage: 0, perPage: perPage) {
                    completion()
                }
            }
        } else {
            fetchAlbums {
                completion()
            }
        }
    }
    
    private func fetchAlbums(completion: @escaping () -> Void) {
        // Use the AlbumProvider to fetch album data. On completion,
        // handle general UI updates and error alerts on the main queue.
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        albumProvider.fetchAlbums(inParentWithId: categoryId,
                                  thumbnailSize: thumnailSize) { [self] error in
            guard let error = error else {
                // No error ► Fetch image data?
                if self.categoryId == 0 {
                    completion()
                    return
                }
                
                // Check that we have an album with ID
                guard let albumId = albumData?.pwgID else {
                    return
                }
                
                // Remember which images belong to this album
                let oldImageIds = Set(albumData?.images?.compactMap({$0.pwgID}) ?? [])

                // Use the ImageProvider to fetch image data. On completion,
                // handle general UI updates and error alerts on the main queue.
                let perPage = AlbumUtilities.numberOfImagesToDownloadPerPage()
                let albumNbImages = self.albumData?.nbImages ?? 0
                let (quotient, remainer) = albumNbImages.quotientAndRemainder(dividingBy: Int64(perPage))
                let lastPage = Int(quotient) + Int(remainer) > 0 ? 1 : 0
                self.fetchImages(ofAlbumWithId: albumId, imageIds: oldImageIds,
                                 fromPage: 0, toPage: lastPage, perPage: perPage,
                                 completion: completion)
                return
            }
            
            // Show the error
            DispatchQueue.main.async { [self] in
                completion()
                self.showError(error)
            }
        }
    }
    
    private func fetchImages(ofAlbumWithId albumId: Int32, imageIds: Set<Int64>,
                             fromPage onPage: Int, toPage lastPage: Int,
                             perPage: Int, completion: @escaping () -> Void) {
        // Use the ImageProvider to fetch image data. On completion,
        // handle general UI updates and error alerts on the main queue.
        imageProvider.fetchImages(ofAlbumWithId: albumId, withQuery: self.query,
                                  sort: .dateCreatedAscending,
                                  fromPage: onPage, perPage: perPage) { [self] fetchedImageIds, totalCount, error in
            guard let error = error else {
                // No error ► Smart album?
                var newLastPage = lastPage
                if albumId < 0 {
                    // Re-calculate number of pages
                    newLastPage = Int(totalCount.quotientAndRemainder(dividingBy: Int64(perPage)).quotient)

                    // Update smart album data
                    if albumData?.nbImages != totalCount {
                        albumData?.nbImages = totalCount
                    }
                    if albumData?.totalNbImages != totalCount {
                        albumData?.totalNbImages = totalCount
                    }
                    // Save changes
                    DispatchQueue.main.async { [self] in
                        do {
                            try mainContext.save()
                        } catch let error as NSError {
                            print("Could not fetch \(error), \(error.userInfo)")
                        }
                    }
                }
                
                // Update number of images in footer
                updateNberOfImagesInFooter()

                // Will not remove fetched images from album image list
                let newImageIds = imageIds.subtracting(fetchedImageIds)
                
                // Should we continue?
                if onPage < newLastPage {
                    // Pursue fetch without HUD
                    DispatchQueue.main.async { [self] in
                        navigationController?.hidePiwigoHUD { }
                    }
                    // Load next page of images
                    self.fetchImages(ofAlbumWithId: albumId, imageIds: newImageIds,
                                     fromPage: onPage + 1, toPage: newLastPage,
                                     perPage: perPage, completion: completion)
                    return
                }
                
                // Done fetching images ► Remove non-fetched images
                DispatchQueue.main.async { [self] in
                    let images = imageProvider.getImages(inContext: mainContext, withIds: newImageIds)
                    albumData?.removeFromImages(Set(images))
                }
                
                completion()
                return
            }
            self.showError(error)
        }
    }
    
    func updateNberOfImagesInFooter() {
        // Update number of images in footer
        DispatchQueue.main.async { [self] in
            let indexPath = IndexPath(item: 0, section: 1)
            if let footer = self.imagesCollection?.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: indexPath) as? NberImagesFooterCollectionReusableView {
                let (shown, total) = getImageCounts()
                footer.noImagesLabel?.text = AlbumUtilities.footerLegend(shown, total)
            }
        }
    }
}
