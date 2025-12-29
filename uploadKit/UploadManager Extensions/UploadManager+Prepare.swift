//
//  UploadManager+Prepare.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import Photos
@preconcurrency import piwigoKit

extension UploadManager
{
    // MARK: - Prepare Image/Video
    func prepare(_ upload: Upload) async -> Void {
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Start preparing image/video")
        
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
        do {
            if upload.localIdentifier.hasPrefix(kIntentPrefix) {
                // Case of an image submitted by an intent
                try await prepareImageFromIntent(for: upload)
                
                // Preparation completed
                upload.setState(.prepared, save: false)
                
                // Investigate next upload request?
                await didEndPreparation()
            }
            else if upload.localIdentifier.hasPrefix(kClipboardPrefix) {
                // Case of an image retrieved from the pasteboard
                try await prepareImageOrVideoInPasteboard(for: upload)
                
                // Preparation completed
                upload.setState(.prepared, save: false)
                
                // Investigate next upload request?
                await didEndPreparation()
            }
            else {
                // Case of an image from the local Photo Library
                /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
                if try await prepareAssetInPhotoLibrary(for: upload)
                {
                    // Preparation completed
                    upload.setState(.prepared, save: false)
                    
                    // Investigate next upload request?
                    await didEndPreparation()
                }
            }
        }
        catch let error {
            switch error {
            case .unacceptedImageFormat, .unacceptedVideoFormat, .unacceptedAudioFormat, .unacceptedDataFormat:
                upload.setState(.formatError, error: error, save: true)
                
            case .cannotStripPrivateMetadata, .videoEncodingError:
                upload.setState(.preparingError, error: error, save: false)
                
            case .missingAsset, .otherError:
                fallthrough
            default:
                upload.setState(.preparingFail, error: error, save: true)
            }
        }
    }
    
    fileprivate func prepareImageFromIntent(for upload: Upload) async throws(PwgKitError) {
        // Get files in the Uploads directory
        var files = [URL]()
        do {
            files = try FileManager.default.contentsOfDirectory(at: DataDirectories.appUploadsDirectory,
                                                                includingPropertiesForKeys: nil,
                                                                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        } catch {
            throw .missingAsset
        }
        
        // Determine non-empty unique file name and extension from identifier
        guard files.isEmpty == false,
              let fileURL = files.filter({$0.lastPathComponent.hasPrefix(upload.localIdentifier)}).first
        else {
            // File not available… deleted?
            throw .missingAsset
        }
        
        // Rename file if requested by user
        upload.fileName = renamedFile(for: upload)
        
        // Launch preparation job (limited to stripping metadata)
        guard fileURL.lastPathComponent.contains("img")
        else { throw .missingAsset }
        
        // Update upload request
        upload.fileType = pwgImageFileType.image.rawValue
        
        // Update state of upload and launch preparation job
        try await prepareImage(atURL: fileURL, for: upload)
    }
    
    private func prepareImageOrVideoInPasteboard(for upload: Upload) async throws(PwgKitError) {
        // Get files in the Uploads directory
        var files = [URL]()
        do {
            // Get complete filename by searching in the Uploads directory
            files = try FileManager.default.contentsOfDirectory(at: DataDirectories.appUploadsDirectory,
                                                                includingPropertiesForKeys: nil,
                                                                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        }
        catch {
            throw .missingAsset
        }
        
        // Determine non-empty unique file name and extension from identifier
        guard files.isEmpty == false,
              let fileURL = files.filter({$0.absoluteString.contains(upload.localIdentifier)}).first else {
            // File not available… deleted?
            throw .missingAsset
        }
        
        // Launch preparation job if file format accepted by Piwigo server
        let fileExt = fileURL.pathExtension.lowercased()
        let fileName = fileURL.lastPathComponent
        if fileName.contains(kImageSuffix) {
            // Set file type
            upload.fileType = pwgImageFileType.image.rawValue
            
            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-img-#" suffix i.e. "SSSS%@-#" where %@ is kImageSuffix
            /// - adding the file extension
            guard let prefixRange = fileName.range(of: kClipboardPrefix),
                  let suffixRange = fileName.range(of: kImageSuffix)
            else { throw .missingAsset }
            upload.fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            
            // Rename file if requested by user
            upload.fileName = renamedFile(for: upload)
            
            // Chek that the image format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Prepare image \(upload.fileName)")
                try await prepareImage(atURL: fileURL, for: upload)
                return
            }
            
            // Try to convert image if JPEG format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Convert image \(upload.fileName) to JPEG format")
                try await convertImage(atURL: fileURL, for: upload)
                return
            }
            
            // Image file format cannot be accepted by the Piwigo server
            throw .unacceptedImageFormat
        }
        else if fileName.contains(kMovieSuffix) {
            // Set file type
            upload.fileType = pwgImageFileType.video.rawValue
            
            // Set filename by
            /// - removing the "Clipboard-" prefix i.e. kClipboardPrefix
            /// - removing the "SSSS-mov-#" suffix i.e. "SSSS%@-#" where %@ is kMovieSuffix
            /// - adding the file extension
            guard let prefixRange = fileName.range(of: kClipboardPrefix),
                  let suffixRange = fileName.range(of: kMovieSuffix)
            else { throw .missingAsset }
            upload.fileName = String(fileName[prefixRange.upperBound..<suffixRange.lowerBound].dropLast(4)) + ".\(fileExt)"
            
            // Rename file if requested by user
            upload.fileName = renamedFile(for: upload)
            
            // Chek that the video format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Prepare video \(upload.fileName)")
                try await prepareVideo(atURL: fileURL, for: upload)
                return
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
                UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Convert video \(upload.fileName) to MP4 format")
                try await convertVideo(atURL: fileURL, for: upload)
                return
            }
            
            // Video file format cannot be accepted by the Piwigo server
            throw .unacceptedVideoFormat
        }
        else {
            // Unknown type
            throw .unacceptedDataFormat
        }
    }
    
    private func prepareAssetInPhotoLibrary(for upload: Upload) async throws(PwgKitError) -> Bool {
        // Retrieve image asset
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil)
        guard assets.count > 0, let originalAsset = assets.firstObject
        else { throw .missingAsset }
        
        // Retrieve creation date from PHAsset (local time, or UTC time if time zone provided)
        if let creationDate = originalAsset.creationDate {
            upload.creationDate = creationDate.timeIntervalSinceReferenceDate
        } else {
            upload.creationDate = Date().timeIntervalSinceReferenceDate
        }
        
        // Get URL of image file to be stored into Piwigo/Uploads directory
        // and deletes temporary image file if exists (incomplete previous attempt?)
        let fileURL = getUploadFileURL(from: upload, withSuffix: kOriginalSuffix, deleted: true)
        
        // Preparation method depends on media type
        switch originalAsset.mediaType {
        case .image:
            // Set filetype
            upload.fileType = pwgImageFileType.image.rawValue
            
            // Get file from asset
            try await writePhotoAsset(originalAsset, toFile: fileURL, for: upload)
            
            // Rename file if requested by user
            upload.fileName = renamedFile(for: upload)
            
            // Launch preparation job according to file format
            let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
            
            // Chek that the image format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Prepare image \(upload.fileName)")
                try await prepareImage(atURL: fileURL, for: upload)
                return true
            }
            
            // Convert image if JPEG format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                UploadManager.logger.notice("\(upload.objectID.uriRepresentation().absoluteString) • Convert image \(upload.fileName) to JPEG format")
                try await convertImage(atURL: fileURL, for: upload)
                return true
            }
            
            // Image file format cannot be accepted by the Piwigo server
            throw PwgKitError.unacceptedImageFormat
            
        case .video:
            // Get filename from asset
            getVideoFileName(from: originalAsset, for: upload)
            
            // Rename file if requested by user
            upload.fileName = renamedFile(for: upload)
            
            // Set filetype
            upload.fileType = pwgImageFileType.video.rawValue
            
            // Launch preparation job according to file format
            let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
            
            // File name of final video data to be stored into Piwigo/Uploads directory
            let outputURL = getUploadFileURL(from: upload, deleted: false)
            
            // Chek that the video format is accepted by the Piwigo server
            /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                UploadManager.logger.notice("Prepare video \(upload.fileName)")
                Task {
                    self.prepareVideo(ofAsset: originalAsset, atURL: outputURL, for: upload)
                }
                return false
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
                UploadManager.logger.notice("Convert video \(upload.fileName) to MP4 format")
                Task {
                    self.convertVideo(ofAsset: originalAsset, atURL: outputURL, for: upload)
                }
                return false
            }
            
            // Video file format cannot be accepted by the Piwigo server
            throw PwgKitError.unacceptedVideoFormat
            
        case .audio:
            // Update state of upload: Not managed by Piwigo iOS yet…
            throw .unacceptedAudioFormat
            
        case .unknown:
            fallthrough
        default:
            throw .unacceptedDataFormat
        }
    }
    
    
    // MARK: - End of Preparation
    func didEndPreparation() async {
        // Running in background or foreground?
        isPreparing = false
        if UploadVars.shared.isExecutingBGUploadTask {
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
            //        } else if UploadVars.shared.isExecutingBGContinuedUploadTask {
            //            // In continued background task, launch a transfer if possible
            //            let prepared = (uploads.fetchedObjects ?? []).filter({$0.state == .prepared})
            //            let states: [pwgUploadState] = [.preparingError, .preparingFail,
            //                                            .uploadingError, .uploadingFail,
            //                                            .finishingError]
            //            let failed = (uploads.fetchedObjects ?? []).filter({states.contains($0.state)})
            //            if isUploading.count < maxNberOfTransfers,
            //               failed.count < maxNberOfFailedUploads,
            //               let upload = prepared.first {
            //                launchTransfer(of: upload)
            //            }
        } else {
            // In foreground, always consider next file
            if isUploading.count <= maxNberOfTransfers, !isFinishing {
                findNextImageToUpload()
            }
        }
    }
    
    
    // MARK: - Utilities
    // Returns the original filename or a name based on a date
    func getFilename(fromName originalFilename: String, ofAsset originalAsset: PHAsset) -> String {
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        var utf8mb3Filename = originalFilename.utf8mb3Encoded
        
        // Snapchat creates filenames containning ":" characters,
        // which prevents the app from storing the converted file
        if #available(iOS 16.0, *) {
            utf8mb3Filename = utf8mb3Filename.replacing(":", with: "")
        } else {
            // Fallback on earlier versions
            utf8mb3Filename = utf8mb3Filename.replacingOccurrences(of: ":", with: "")
        }
        
        // If filename is empty, create one from the current date
        if utf8mb3Filename.isEmpty {
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
        
        return utf8mb3Filename
    }
    
    // Rename file according to user's demand
    fileprivate func renamedFile(for upload: Upload) -> String {
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
        if let user = upload.user,
           let album = try? AlbumProvider().getAlbum(ofUser: user, withId: upload.category) {
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
        return fileName.utf8mb3Encoded
    }
    
    /// - Rename Upload file if needed
    /// - Get MD5 checksum and MIME type
    /// - Update upload session counter
    /// -> return updated upload properties w/ or w/o error
    func finalizeImageFile(atURL originalFileURL: URL, with upload: Upload) throws(PwgKitError) {

        // File name of image data to be stored into Piwigo/Uploads directory
        let fileURL = getUploadFileURL(from: upload)
        
        // Should we rename the file to adopt the Upload Manager convention?
        if originalFileURL != fileURL {
            // Deletes temporary Upload file if it exists (incomplete previous attempt?)
            try? FileManager.default.removeItem(at: fileURL)

            // Adopts Upload filename convention (e.g. removes the "-original" suffix)
            do {
                try FileManager.default.moveItem(at: originalFileURL, to: fileURL)
            }
            catch let error as CocoaError {
                // Update upload request state
                throw .fileOperationFailed(innerError: error)
            }
            catch {
                throw .otherError(innerError: error)
            }
        }
        
        // Set creation date as the photo creation date
        let creationDate = NSDate(timeIntervalSinceReferenceDate: upload.creationDate)
        let attrs = [FileAttributeKey.creationDate     : creationDate,
                     FileAttributeKey.modificationDate : creationDate]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path)
        
        // Determine MD5 checksum of image file to upload
        upload.md5Sum = try fileURL.MD5checksum()
        
        // Get MIME type from file extension
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        guard let uti = UTType(filenameExtension: fileExt),
              let mimeType = uti.preferredMIMEType
        else {
            throw .missingAsset
        }
        upload.mimeType = mimeType

        // Done -> append file size to counter
        countOfBytesPrepared += UInt64(fileURL.fileSize)
    }
}
