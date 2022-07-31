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
    func reloginAndReloadAlbumData(completion: @escaping () -> Void) {
        /// - Pause upload operations
        /// - Perform relogin
        /// - Reload album data
        /// - Resume upload operations in background queue
        ///   and update badge, upload button of album navigator
        UploadManager.shared.isPaused = true

        // Display HUD when loading album data for the first time
        if AppVars.shared.nberOfAlbumsInCache == 0 {
            let title = NSLocalizedString("login_loggingIn", comment: "Logging In...")
            let detail = NSLocalizedString("login_connecting", comment: "Connecting")
            DispatchQueue.main.async { [unowned self] in
                navigationController?.showPiwigoHUD(
                    withTitle: title, detail: detail,
                    buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                    buttonTarget: self, buttonSelector: #selector(cancelLoggingIn),
                    inMode: .indeterminate)
            }
        }

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
            showErrorAndReturnToLoginView(error)
        } didFailSecureConnection: { [unowned self] error in
            showErrorAndReturnToLoginView(error)
        } failure: { [unowned self] error in
            showErrorAndReturnToLoginView(error)
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
                    showErrorAndReturnToLoginView(error)
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
            showErrorAndReturnToLoginView(nil)
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
            // Display HUD when loading album data for the first time
            if AppVars.shared.nberOfAlbumsInCache == 0 {
                DispatchQueue.main.async { [unowned self] in
                    navigationController?.showPiwigoHUD(
                        withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
                        detail: NSLocalizedString("login_newSession", comment: "Opening Session"),
                        buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                        buttonTarget: self, buttonSelector: #selector(cancelLoggingIn),
                        inMode: .indeterminate)
                }
            }
            
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
                    showErrorAndReturnToLoginView(NetworkVars.userCancelledCommunication ? nil : error)
                }
        }
    }

    func getCommunityStatus(completion: @escaping () -> Void) {
        // Did the user cancel communication?
        if NetworkVars.userCancelledCommunication {
            showErrorAndReturnToLoginView(nil)
            return
        }
        
        if NetworkVars.usesCommunityPluginV29 {
            // Display HUD when loading album data for the first time
            if AppVars.shared.nberOfAlbumsInCache == 0 {
                DispatchQueue.main.async { [unowned self] in
                    navigationController?.showPiwigoHUD(
                        withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
                        detail: NSLocalizedString("login_communityParameters", comment: "Community Parameters"),
                        buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                        buttonTarget: self, buttonSelector: #selector(cancelLoggingIn),
                        inMode: .indeterminate)
                }
            }

            // Community extension installed
            LoginUtilities.communityGetStatus { [unowned self] in
                // Check Piwigo version, get token, available sizes, etc.
                getSessionStatus() {
                    completion()
                }
            } failure: { [unowned self] error in
                // Inform user that server failed to retrieve Community parameters
                showErrorAndReturnToLoginView(NetworkVars.userCancelledCommunication ? nil : error)
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
            showErrorAndReturnToLoginView(nil)
            return
        }
        
        // Display HUD when loading album data for the first time
        if AppVars.shared.nberOfAlbumsInCache == 0 {
            DispatchQueue.main.async { [unowned self] in
                navigationController?.showPiwigoHUD(
                    withTitle: NSLocalizedString("login_loggingIn", comment: "Logging In..."),
                    detail: NSLocalizedString("login_serverParameters", comment: "Piwigo Parameters"),
                    buttonTitle: NSLocalizedString("internetCancelledConnection_button", comment: "Cancel Connection"),
                    buttonTarget: self, buttonSelector: #selector(cancelLoggingIn),
                    inMode: .indeterminate)
            }
        }
        
        LoginUtilities.sessionGetStatus { [unowned self] in
            DispatchQueue.main.async { [unowned self] in
                print("••> Reload album data…")
                reloadAlbumData {
                    // Resume upload operations in background queue
                    // and update badge, upload button of album navigator
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.resumeAll()
                    }
                    completion()
                }
            }
        } failure: { [self]  error in
            showErrorAndReturnToLoginView(error)
        }
    }
    
    func reloadAlbumData(completion: @escaping () -> Void) {
        // Display HUD while downloading albums data recursively
        navigationController?.showPiwigoHUD(
            withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
            detail: NSLocalizedString("tabBar_albums", comment: "Albums"),
            buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Load category data in recursive mode
        AlbumUtilities.getAlbums { didUpdateCats in
            DispatchQueue.main.async { [self] in
                // Check data source and reload collection if needed
                checkDataSource(withChangedCategories: didUpdateCats) { [self] in
                    // Hide HUD
                    navigationController?.hidePiwigoHUD() {
                        completion()
                    }

                    // Update other album views
                    if #available(iOS 13.0, *) {
                        // Refresh other album views if any
                        DispatchQueue.main.async { [self] in
                            // Loop over all other active scenes
                            let sessionID = view.window?.windowScene?.session.persistentIdentifier ?? ""
                            let connectedScenes = UIApplication.shared.connectedScenes
                                .filter({[.foregroundActive].contains($0.activationState)})
                                .filter({$0.session.persistentIdentifier != sessionID})
                            for scene in connectedScenes {
                                if let windowScene = scene as? UIWindowScene,
                                   let albumVC = windowScene.topMostViewController() as? AlbumViewController {
                                    albumVC.checkDataSource(withChangedCategories: didUpdateCats) { }
                                }
                            }
                        }
                    }
                    
                    // Load favorites in the background if necessary
                    AlbumUtilities.loadFavoritesInBckg()
                }
            }
        } failure: { error in
            DispatchQueue.main.async { [self] in
                // Set navigation bar buttons
                initButtonsInSelectionMode()
                // Hide HUD if needed
                navigationController?.hidePiwigoHUD() { [self] in
                    dismissPiwigoError(withTitle: "", message: error.localizedDescription) { }
                }
                completion()
            }
        }
    }

    func checkDataSource(withChangedCategories didChange: Bool,
                         completion: @escaping () -> Void) {
        print(String(format: "checkDataSource...=> ID:%ld - Categories did change:%@",
                     categoryId, didChange ? "YES" : "NO"))

        // Does this album still exist?
        let album = CategoriesData.sharedInstance().getCategoryById(categoryId)
        if categoryId > 0, album == nil {
            // This album does not exist anymore
            let VCs = navigationController?.children
            var index = (VCs?.count ?? 0) - 1
            while index >= 0 {
                if let vc = VCs?[index] as? AlbumViewController {
                    if vc.categoryId == 0 || CategoriesData.sharedInstance().getCategoryById(vc.categoryId) != nil {
                        // Present the album
                        navigationController?.popToViewController(vc, animated: true)
                        completion()
                        return
                    }
                }
                index -= 1
            }
            // We did not find a parent album — should never happen…
            completion()
            return
        }

        // Root album -> reload collection
        if categoryId == 0 {
            if didChange {
                // Reload album collection
                imagesCollection?.reloadData()
                // Set navigation bar buttons
                updateButtonsInPreviewMode()
            }
            completion()
            return
        }
        
        // Other album -> Reload albums
        if didChange, categoryId >= 0 {
            // Update header
            albumDescription = AlbumUtilities.headerLegend(for: categoryId)
            // Reload album collection
            imagesCollection?.reloadSections(IndexSet(integer: 0))
            // Set navigation bar buttons
            updateButtonsInPreviewMode()
        }

        // Other album —> If the number of images in cache is null, reload collection
        if album == nil || album?.imageList?.count == 0 {
            // Something did change… reset album data
            albumData = AlbumData(categoryId: categoryId, andQuery: "")
            // Reload collection
            if categoryId < 0 {
                // Load, sort images and reload collection
                albumData?.updateImageSort(kPiwigoSortObjc(rawValue: UInt32(AlbumVars.shared.defaultSort)), onCompletion: { [self] in
                    // Reset navigation bar buttons after image load
                    updateButtonsInPreviewMode()
                    imagesCollection?.reloadData()
                }, onFailure: { [unowned self] _, error in
                    dismissPiwigoError(withTitle: NSLocalizedString("albumPhotoError_title", comment: "Get Album Photos Error"), message: NSLocalizedString("albumPhotoError_message", comment: "Failed to get album photos (corrupt image in your album?)"), errorMessage: error?.localizedDescription ?? "") { }
                })
            } else {
                imagesCollection?.reloadSections(IndexSet(integer: 1))
            }
            // Cancel selection
            cancelSelect()
        }
        completion()
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

    private func showErrorAndReturnToLoginView(_ error: Error?) {
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
}
