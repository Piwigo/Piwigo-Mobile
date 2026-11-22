//
//  ImageViewController+Location.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Adds or adjusts the location of a photo.
//  The Piwigo API cannot set the latitude and longitude of an image: the server reads them from the file,
//  so the app writes the GPS tags into the original file and replaces the file of the image on the server.
//

import Foundation
import UIKit
import CoreLocation
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit
import PwgMetadataKit

// MARK: Add or Adjust Location
extension ImageViewController
{
    // MARK: - Menu
    /// The location is written in JPEG, TIFF and HEIF files, the formats which ImageIO rewrites and the server reads.
    /// Rights are the ones of the other edition commands: this command belongs to the menu which they open.
    func canEditLocation(of image: Image?) -> Bool {
        guard let image, image.isVideo == false, image.isPDF == false,
              image.fileName.isEmpty == false
        else { return false }
        return ImageGpsWriter.canWriteLocation(inFileWithExtension: URL(fileURLWithPath: image.fileName).pathExtension)
    }

    @MainActor
    func locationAction() -> UIAction? {
        guard canEditLocation(of: imageData) else { return nil }
        let hasLocation = metadataCoordinate(of: imageData) != nil
        let title = hasLocation
            ? String(localized: "imageOptions_adjustLocation", comment: "Adjust Location")
            : String(localized: "imageOptions_addLocation", comment: "Add Location")
        let action = UIAction(title: title, image: UIImage(systemName: "mappin.and.ellipse"),
                              handler: { [weak self] _ in
            self?.editLocation()
        })
        action.accessibilityIdentifier = hasLocation ? "Adjust Location" : "Add Location"
        return action
    }

    /// Called by the menu and by the location of the metadata panel
    @MainActor
    @objc func editLocation() {
        guard let imageData, canEditLocation(of: imageData) else { return }
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Present the panel choosing the location
        let locationSB = UIStoryboard(name: "LocationPanelViewController", bundle: nil)
        guard let locationVC = locationSB.instantiateViewController(withIdentifier: "LocationPanelViewController") as? LocationPanelViewController
        else { preconditionFailure("Could not instantiate LocationPanelViewController") }
        locationVC.originalCoordinate = metadataCoordinate(of: imageData)
        locationVC.delegate = self
        pushView(locationVC, forButton: actionBarButton)
    }


    // MARK: - Update
    private struct LocationUpdateError: Error {
        let message: String
    }

    /// Downloads the original file if needed, writes the new position in a copy, replaces the file of the image on the server,
    /// then refreshes the cache.
    @MainActor
    func updateLocation(to coordinate: CLLocationCoordinate2D) {
        guard let imageData, canEditLocation(of: imageData) else {
            setEnableStateOfButtons(true)
            return
        }

        // Original file: the URL of the full resolution, or the one for downloading (since Piwigo 14).
        /// The sizes picked for sharing are not appropriate: the original is not chosen when it is not larger
        /// than the largest size the server generated, whereas only the original holds the metadata to change.
        let imageSize = pwgImageSize.fullRes
        let fullResURL = (imageData.fullRes?.url as URL?).flatMap { $0.absoluteString.isEmpty ? nil : $0 }
        guard let serverID = imageData.server?.uuid,
              let imageURL = fullResURL ?? (imageData.downloadUrl as URL?)
        else {
            showLocationError(PwgKitError.failedToPrepareDownload.localizedDescription)
            return
        }
        let imageID = imageData.pwgID
        let fileName = imageData.fileName
        let fileSize = imageData.fileSize
        let currentAlbumID = categoryId

        // The HUD shows the progress of the download then of the upload
        showHUD(withTitle: String(localized: "locationHUD_updating", comment: "Updating Location…"), inMode: .determinate)

        Task {
            let workDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: workDirectory) }
            do {
                try await LoginUtilities().checkSessionOfCurrentUser()

                // Properties which the metadata of the new file must not change, as the server holds them now
                let info = try await JSONManager.shared.getInfos(forID: imageID)
                let albumIDs = (info.categories ?? []).compactMap(\.id)
                let albumID = currentAlbumID > 0 && (albumIDs.isEmpty || albumIDs.contains(currentAlbumID))
                    ? currentAlbumID : (albumIDs.first ?? currentAlbumID)
                guard albumID > 0 else { throw LocationUpdateError(message: PwgKitError.missingAlbumData.localizedDescription) }

                // Original file, from the cache if it is there
                let cachedURL: URL = try await withCheckedThrowingContinuation { continuation in
                    Task {
                        await ImageDownloader.shared.getImage(withID: imageID, ofSize: imageSize, type: .album, atURL: imageURL,
                                                              fromServer: serverID, fileSize: fileSize) { fraction in
                            Task { @MainActor in self.updateHUD(withProgress: 0.4 * fraction) }
                        } completion: { fileURL in
                            continuation.resume(returning: fileURL)
                        } failure: { error in
                            continuation.resume(throwing: error)
                        }
                    }
                }

                // Copy of the file with the new position
                let sourceDirectory = workDirectory.appendingPathComponent("source")
                let modifiedDirectory = workDirectory.appendingPathComponent("modified")
                try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: modifiedDirectory, withIntermediateDirectories: true)
                let sourceURL = sourceDirectory.appendingPathComponent(fileName)
                let modifiedURL = modifiedDirectory.appendingPathComponent(fileName)
                try FileManager.default.copyItem(at: cachedURL, to: sourceURL)
                try ImageGpsWriter.write(latitude: coordinate.latitude, longitude: coordinate.longitude,
                                         from: sourceURL, to: modifiedURL)
                await MainActor.run { updateHUD(withProgress: 0.45) }
                let modifiedMD5 = try Data(contentsOf: modifiedURL, options: .alwaysMapped).MD5checksum

                // Replace the file on the server
                let replacement = ImageFileReplacement(
                    imageID: imageID, albumID: albumID, fileURL: modifiedURL, fileName: info.fileName ?? fileName,
                    title: info.title ?? "", author: info.author ?? "", comment: info.commentRaw ?? info.comment ?? "",
                    dateCreated: info.dateCreated ?? "", privacyLevel: info.privacyLevel ?? "0",
                    tagIDs: (info.tags ?? []).compactMap { $0.id?.int64Value }.map(String.init).joined(separator: ","))
                var uploadError: PwgKitError?
                do throws(PwgKitError) {
                    try await ImageFileReplacer.replace(with: replacement) { fraction in
                        Task { @MainActor in self.updateHUD(withProgress: 0.45 + 0.5 * fraction) }
                    }
                } catch {
                    /// The server may have processed the file although its reply is unusable (plugins print warnings
                    /// and errors around the JSON): the checksum of the image tells.
                    uploadError = error
                }

                // Image data after the replacement
                let fetchedInfo = try? await JSONManager.shared.getInfos(forID: imageID)
                if let uploadError, fetchedInfo?.md5checksum != modifiedMD5 {
                    throw uploadError
                }
                guard var newInfo = fetchedInfo else { throw LocationUpdateError(message: PwgKitError.fetchImageFailed.localizedDescription) }
                newInfo.fixingUnknowns()

                // The checksum changed: the files in cache are deleted, those of the new file will be downloaded
                try await ImageProvider().importImages([newInfo], inAlbum: currentAlbumID, sort: .albumDefault)
                await MainActor.run { self.locationDidChange() }
            }
            catch {
                await MainActor.run {
                    // Session logout required?
                    if let error = error as? PwgKitError, error.requiresLogout, self.userData.pwgID != 0 {
                        ClearCache.closeSessionWithPwgError(from: self, error: error)
                        return
                    }
                    self.showLocationError((error as? LocationUpdateError)?.message ?? error.localizedDescription)
                }
            }
        }
    }

    /// The server holds the new file: the page, the menu and the metadata show the new location
    @MainActor
    private func locationDidChange() {
        updateHUDwithSuccess { [self] in
            hideHUD(afterDelay: pwgDelayHUD) { [self] in
                setEnableStateOfButtons(true)
                updateNavBar()
                if let metadataVC = metadataPanel.cardViewController ?? metadataPanel.viewController {
                    configureMetadata(of: metadataVC)
                }
                (pageViewController?.viewControllers?.first as? ImageDetailViewController)?.downloadHighResImageIfMissing()
            }
        }
    }

    @MainActor
    private func showLocationError(_ errorMessage: String) {
        hideHUD { [self] in
            setEnableStateOfButtons(true)
            let alert = UIAlertController(title: String(localized: "locationFail_title", comment: "Location Not Updated"),
                                          message: String.localizedStringWithFormat(
                                            String(localized: "locationFail_message", comment: "The location of the photo could not be changed.\n%@"),
                                            errorMessage),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Localized.dismiss, style: .cancel))
            alert.view.tintColor = PwgColor.tintColor
            present(alert, animated: true) {
                alert.view.tintColor = PwgColor.tintColor
            }
        }
    }
}


// MARK: - LocationPanelDelegate Methods
extension ImageViewController: LocationPanelDelegate
{
    func locationPanel(_ panel: LocationPanelViewController, didChoose coordinate: CLLocationCoordinate2D) {
        updateLocation(to: coordinate)
    }

    func locationPanelDidCancel(_ panel: LocationPanelViewController) {
        setEnableStateOfButtons(true)
    }
}
