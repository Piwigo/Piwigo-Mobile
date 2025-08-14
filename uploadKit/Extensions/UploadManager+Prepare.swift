//
//  UploadManager+Prepare.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
import piwigoKit

extension UploadManager
{
    // MARK: - Prepare Image/Video
    func prepare(_ upload: Upload) -> Void {
        if #available(iOSApplicationExtension 14.0, *) {
            UploadManager.logger.notice("Prepare image/video for upload \(upload.objectID.uriRepresentation())")
        }

        // Update upload status
        isPreparing = true
        upload.setState(.preparing, save: true)

        // Add category ID to list of recently used albums
        let userInfo = ["categoryId": upload.category]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Determine from where the file comes from:
        // => Photo Library: use PHAsset local identifier
        // => UIPasteborad: use identifier of type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        // => Intent: use identifier of type "Intent-yyyyMMdd-HHmmssSSSS-typ-#"
        //    where "typ" is "img" (photo) or "mov" (video).
        if upload.localIdentifier.hasPrefix(kIntentPrefix) {
            // Case of an image submitted by an intent
            prepareImageFromIntent(for: upload)
        } else if upload.localIdentifier.hasPrefix(kClipboardPrefix) {
            // Case of an image retrieved from the pasteboard
            prepareImageInPasteboard(for: upload)
        } else {
            // Case of an image from the local Photo Library
            prepareImageInPhotoLibrary(for: upload)
        }
    }
    
    private func renamedFile(for upload: Upload) -> String {
        // Anything to do?
        var fileName = upload.fileName
        if upload.fileNamePrefixEncodedActions.isEmpty,
           upload.fileNameReplaceEncodedActions.isEmpty,
           upload.fileNameSuffixEncodedActions.isEmpty,
           FileExtCase(rawValue: upload.fileNameExtensionCase) == .keep {
            // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
            return fileName.utf8mb3Encoded
        }
        
        // Get album current counter value
        var currentCounter = UploadVars.shared.categoryCounterInit
        if let album = albumProvider.getAlbum(ofUser: upload.user, withId: upload.category) {
            // Album available ► Get current counter
            if album.isFault {
                // The album is not fired yet.
                album.willAccessValue(forKey: nil)
                album.didAccessValue(forKey: nil)
            }
            currentCounter = album.currentCounter

            // Increment album counter
            album.currentCounter += 1
        }
        
        // Rename the file
        let prefixActions = upload.fileNamePrefixEncodedActions.actions
        let replaceActions = upload.fileNameReplaceEncodedActions.actions
        let suffixActions = upload.fileNameSuffixEncodedActions.actions
        let caseOfExtension = FileExtCase(rawValue: upload.fileNameExtensionCase) ?? .keep
        let creationDate = Date(timeIntervalSinceReferenceDate: upload.creationDate)
        fileName.renameFile(prefixActions: prefixActions,
                            replaceActions: replaceActions,
                            suffixActions: suffixActions,
                            caseOfExtension: caseOfExtension,
                            albumID: upload.category,
                            date: creationDate,
                            counter: currentCounter)
                
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        return fileName
    }
    
    private func prepareImageFromIntent(for upload: Upload) {
        // Determine non-empty unique file name and extension from identifier
        var files = [URL]()
        do {
            // Get complete filename by searching in the Uploads directory
            files = try FileManager.default.contentsOfDirectory(at: uploadsDirectory,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        }
        catch {
            files = []
        }
        guard files.count > 0,
              let fileURL = files.filter({$0.lastPathComponent.hasPrefix(upload.localIdentifier)}).first else {
            // File not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
            return
        }
        
        // Rename file if requested by user
        upload.fileName = renamedFile(for: upload)

        // Launch preparation job (limited to stripping metadata)
        if fileURL.lastPathComponent.contains("img") {
            upload.fileType = pwgImageFileType.image.rawValue

            // Update state of upload and launch preparation job
            prepareImage(atURL: fileURL, for: upload)
            return
        }
    }
    
    private func prepareImageInPasteboard(for upload: Upload) {
        // Determine non-empty unique file name and extension from identifier
        var files = [URL]()
        do {
            // Get complete filename by searching in the Uploads directory
            files = try FileManager.default.contentsOfDirectory(at: uploadsDirectory,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        }
        catch {
            files = []
        }
        guard files.count > 0,
              let fileURL = files.filter({$0.absoluteString.contains(upload.localIdentifier)}).first else {
            // File not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
            return
        }
        let fileName = fileURL.lastPathComponent

        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = fileURL.pathExtension.lowercased()
        if fileName.contains("img") {
            upload.fileType = pwgImageFileType.image.rawValue

            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-img-#" suffix i.e. "SSSS%@-#" where %@ is kImageSuffix
            /// - adding the file extension
            if let prefixRange = fileName.range(of: kClipboardPrefix),
               let suffixRange = fileName.range(of: kImageSuffix) {
                upload.fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            }

            // Rename file if requested by user
            upload.fileName = renamedFile(for: upload)

            // Chek that the image format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Prepare image \(upload.fileName)")
                }
                prepareImage(atURL: fileURL, for: upload)
                return
            }
            
            // Try to convert image if JPEG format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Convert image \(upload.fileName) to JPEG format")
                }
                convertImage(atURL: fileURL, for: upload)
                return
            }
            
            // Image file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: UploadError.wrongDataFormat, save: true)
            
            // Update upload request
            didEndPreparation()
        }
        else if fileName.contains("mov") {
            upload.fileType = pwgImageFileType.video.rawValue

            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-mov-#" suffix i.e. "SSSS%@-#" where %@ is kMovieSuffix
            /// - adding the file extension
            if let prefixRange = fileName.range(of: kClipboardPrefix),
               let suffixRange = fileName.range(of: kMovieSuffix) {
                upload.fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            }

            // Rename file if requested by user
            upload.fileName = renamedFile(for: upload)

            // Chek that the video format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Prepare video \(upload.fileName)")
                }
                prepareVideo(atURL: fileURL, for: upload)
                return
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Convert video \(upload.fileName) to MP4 format")
                }
                convertVideo(atURL: fileURL, for: upload)
                return
            }
            
            // Video file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: UploadError.wrongDataFormat, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
        }
        else {
            // Unknown type
            upload.setState(.formatError, error: UploadError.wrongDataFormat, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
        }
    }
    
    private func prepareImageInPhotoLibrary(for upload: Upload) {
        // Retrieve image asset
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil)
        guard assets.count > 0, let originalAsset = assets.firstObject else {
            // Asset not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset, save: true)
            
            self.didEndPreparation()
            return
        }

        // Retrieve creation date from PHAsset (local time, or UTC time if time zone provided)
        if let creationDate = originalAsset.creationDate {
            upload.creationDate = creationDate.timeIntervalSinceReferenceDate
        } else {
            upload.creationDate = Date().timeIntervalSinceReferenceDate
        }
        
        // Get URL of image file to be stored into Piwigo/Uploads directory
        // and deletes temporary image file if exists (incomplete previous attempt?)
        let fileURL = getUploadFileURL(from: upload, withSuffix: kOriginalSuffix, deleted: true)

        // Retrieve asset resources
        var resources = PHAssetResource.assetResources(for: originalAsset)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let edited = resources.first(where: { $0.type == .fullSizePhoto || $0.type == .fullSizeVideo })
        let original = resources.first(where: { $0.type == .photo || $0.type == .video || $0.type == .audio })
        let resource = edited ?? original ?? resources.first(where: { $0.type == .alternatePhoto})
        let originalFilename = original?.originalFilename ?? ""

        // Priority to original media data
        if let res = resource {
            // Store original data in file
            PHAssetResourceManager.default().writeData(for: res, toFile: fileURL,
                                                       options: options) { error in
                // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
                var utf8mb3Filename = originalFilename.utf8mb3Encoded
                
                // Snapchat creates filenames containning ":" characters,
                // which prevents the app from storing the converted file
                utf8mb3Filename = utf8mb3Filename.replacingOccurrences(of: ":", with: "")
                
                // If encodedFileName is empty, build one from the current date
                if utf8mb3Filename.count == 0 {
                    // No filename => Build filename from creation date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
                    if let creation = originalAsset.creationDate {
                        utf8mb3Filename = dateFormatter.string(from: creation)
                    } else {
                        utf8mb3Filename = dateFormatter.string(from: Date())
                    }

                    // Filename extension required by Piwigo so that it knows how to deal with it
                    if originalAsset.mediaType == .image {
                        // Adopt JPEG photo format by default, will be rechecked
                        utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("jpg").lastPathComponent
                    } else if originalAsset.mediaType == .video {
                        // Videos are exported in MP4 format
                        utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("mp4").lastPathComponent
                    } else if originalAsset.mediaType == .audio {
                        // Arbitrary extension, not managed yet
                        utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("m4a").lastPathComponent
                    }
                }
                
                upload.fileName = utf8mb3Filename
                self.dispatchAsset(originalAsset, atURL:fileURL, for: upload)
            }
        }
        else {
            // Asset not available… deleted?
            upload.setState(.preparingFail, error: UploadError.missingAsset, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
        }
        
        // Release memory
        resources.removeAll(keepingCapacity: false)
    }
    
    private func dispatchAsset(_ originalAsset:PHAsset, atURL uploadFileURL:URL, for upload: Upload) {
        // Rename file if requested by user
        upload.fileName = renamedFile(for: upload)

        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        switch originalAsset.mediaType {
        case .image:
            upload.fileType = pwgImageFileType.image.rawValue
            // Chek that the image format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Prepare image \(upload.fileName)")
                }
                self.prepareImage(atURL: uploadFileURL, for: upload)
                return
            }
            // Convert image if JPEG format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Convert image \(upload.fileName) to JPEG format")
                }
                self.convertImage(atURL: uploadFileURL, for: upload)
                return
            }

            // Image file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: UploadError.wrongDataFormat, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
//            showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_format", comment: "Sorry, image files with extensions .\(fileExt.uppercased()) and .jpg are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)

        case .video:
            upload.fileType = pwgImageFileType.video.rawValue
            // Chek that the video format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Prepare video \(upload.fileName)")
                }
                self.prepareVideo(ofAsset: originalAsset, for: upload)
                return
            }
            // Convert video if MP4 format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
                if #available(iOSApplicationExtension 14.0, *) {
                    UploadManager.logger.notice("Convert video \(upload.fileName) to MP4 format")
                }
                self.convertVideo(ofAsset: originalAsset, for: upload)
                return
            }
            
            // Video file format cannot be accepted by the Piwigo server
            upload.setState(.formatError, error: UploadError.wrongDataFormat, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
//                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt.uppercased()) are not accepted by the Piwigo server."), forRetrying: false, withImage: uploadToPrepare)

        case .audio:
            // Update state of upload: Not managed by Piwigo iOS yet…
            upload.setState(.formatError, error: UploadError.wrongDataFormat, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
//            showError(withTitle: NSLocalizedString("audioUploadError_title", comment: "Audio Upload Error"), andMessage: NSLocalizedString("audioUploadError_format", comment: "Sorry, audio files are not supported by Piwigo Mobile yet."), forRetrying: false, withImage: uploadToPrepare)

        case .unknown:
            fallthrough
        default:
            // Update state of upload request: Unknown format
            upload.setState(.formatError, error: UploadError.wrongDataFormat, save: true)
            
            // Investigate next upload request?
            self.didEndPreparation()
        }
    }

    
    // MARK: - End of Preparation
    func didEndPreparation() {
        // Running in background or foreground?
        isPreparing = false
        if isExecutingBackgroundUploadTask {
            if countOfBytesToUpload < maxCountOfBytesToUpload {
                // In background task, launch a transfer if possible
                let prepared = (uploads.fetchedObjects ?? []).filter({$0.state == .prepared})
                let states: [pwgUploadState] = [.preparingError, .preparingFail,
                                                .uploadingError, .uploadingFail,
                                                .finishingError]
                let failed = (uploads.fetchedObjects ?? []).filter({states.contains($0.state)})
                if isUploading.count < maxNberOfTransfers,
                   failed.count < maxNberOfFailedUploads,
                   let upload = prepared.first {
                    launchTransfer(of: upload)
                }
            }
        } else {
            // In foreground, always consider next file
            if isUploading.count <= maxNberOfTransfers, !isFinishing {
                findNextImageToUpload()
            }
        }
    }
}
