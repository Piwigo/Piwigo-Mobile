//
//  UploadManager+Prepare.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 23/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import Photos
import piwigoKit

@UploadManagerActor
extension UploadManager
{
    // MARK: - Prepare Image/Video
    func nberOfUploadsInPreparation() async -> Int {
        let pending = (try? self.uploadBckgContext.fetch(fetchPendingRequest)) ?? []
        return pending.filter({ [.prepared, .preparing].contains($0.state) }).count
    }
    
    func prepareUpload(withID uploadID: NSManagedObjectID) async -> Void {
        
        // Retrieve upload request in context of actor
        guard let upload = try? self.uploadBckgContext.existingObject(with: uploadID) as? Upload
        else {
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Could not retrieve upload request for preparation!")
            return
        }
        
        // Check upload status
        guard upload.state == .waiting
        else {
            UploadManager.logger.notice("\(upload.objectID.uriRepresentation().lastPathComponent) • Upload in wrong state '\(upload.stateLabel)' before preparation")
            return
        }
        
        // Update upload status
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Start preparing upload")
        upload.setState(.preparing)
        upload.managedObjectContext?.saveIfNeeded()
        
        // Add category ID to list of recently used albums
        let userInfo = ["categoryId": upload.category]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
        
        // Update progress bar
        let localIdentifier = upload.localIdentifier
        DispatchQueue.main.async {
            let uploadInfo: [String : Any] = ["localIdentifier" : localIdentifier,
                                              "progressFraction" : 0.0]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
        
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
            }
            else if upload.localIdentifier.hasPrefix(kClipboardPrefix) {
                // Case of an image retrieved from the pasteboard
                try await prepareImageOrVideoInPasteboard(for: upload)
            }
            else {
                // Case of an image from the local Photo Library
                if try await prepareAssetInPhotoLibrary(for: upload) == false {
                    return
                }
            }
            
            // Preparation completed
            upload.setState(.prepared)
            upload.managedObjectContext?.saveIfNeeded()
        }
        catch let error {
            switch error {
            case .unacceptedImageFormat, .unacceptedVideoFormat, .unacceptedAudioFormat, .unacceptedDataFormat:
                upload.setState(.formatError, error: error)
                upload.managedObjectContext?.saveIfNeeded()
            case .cannotStripPrivateMetadata, .videoEncodingError:
                upload.setState(.preparingError, error: error)
                upload.managedObjectContext?.saveIfNeeded()
            case .missingAsset, .otherError:
                fallthrough
            default:
                upload.setState(.preparingFail, error: error)
                upload.managedObjectContext?.saveIfNeeded()
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
              let fileURL = files.filter({$0.lastPathComponent.hasPrefix(upload.localIdentifier)}).first,
              fileURL.lastPathComponent.contains("img")
        else {
            // File not available… deleted?
            throw .missingAsset
        }
                
        // Set file name and type
        upload.fileType = pwgImageFileType.image.rawValue
        upload.fileName = renamedFile(for: upload)         // Rename file if requested by user
        upload.managedObjectContext?.saveIfNeeded()
        
        // Launch preparation job (limited to stripping metadata)
        try await prepareImage(atURL: fileURL, for: upload)
    }
    
    fileprivate func prepareImageOrVideoInPasteboard(for upload: Upload) async throws(PwgKitError) {
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
            // Get filename from URL components
            let filename = try getFilenameForImageInPasteboard(withName: fileName, extension: fileExt)
            
            // Set file name and type
            upload.fileType = pwgImageFileType.image.rawValue
            upload.fileName = filename
            upload.fileName = renamedFile(for: upload)         // Rename file if requested by user
            upload.managedObjectContext?.saveIfNeeded()
            
            // Chek that the image format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                try await prepareImage(atURL: fileURL, for: upload)
                return
            }
            
            // Try to convert image if JPEG format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                try await convertImage(atURL: fileURL, for: upload)
                return
            }
            
            // Image file format cannot be accepted by the Piwigo server
            throw .unacceptedImageFormat
        }
        else if fileName.contains(kMovieSuffix) {
            // Get filename from URL components
            let filename = try getFilenameForVideoInPasteboard(withName: fileName, extension: fileExt)
            
            // Set file name and type
            upload.fileType = pwgImageFileType.video.rawValue
            upload.fileName = filename
            upload.fileName = renamedFile(for: upload)         // Rename file if requested by user
            upload.managedObjectContext?.saveIfNeeded()
            
            // Chek that the video format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                try await prepareVideo(atURL: fileURL, for: upload)
                return
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
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
    
    /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
    /// so we use old method with completion handler and return false in that case.
    fileprivate func prepareAssetInPhotoLibrary(for upload: Upload) async throws(PwgKitError) -> Bool {
        // Retrieve image asset
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [upload.localIdentifier], options: nil)
        guard assets.count > 0, let originalAsset = assets.firstObject
        else { throw .missingAsset }
        
        // Get URL of image file to be stored into Piwigo/Uploads directory
        // and deletes temporary image file if exists (incomplete previous attempt?)
        let fileURL = getUploadFileURL(from: upload.localIdentifier, withSuffix: kOriginalSuffix,
                                       creationDate: upload.creationDate, deleted: true)
        
        // Preparation method depends on media type
        switch originalAsset.mediaType {
        case .image:
            // Create file from asset and get filename
            let filename = try await writePhotoFromAsset(originalAsset, toFile: fileURL, for: upload)
            
            // Update upload request
            upload.fileType = pwgImageFileType.image.rawValue
            upload.fileName = filename
            upload.fileName = renamedFile(for: upload)         // Rename file if requested by user
            
            // Retrieve creation date from PHAsset (local time, or UTC time if time zone provided)
            if let creationDate = originalAsset.creationDate {
                upload.creationDate = creationDate.timeIntervalSinceReferenceDate
            } else {
                upload.creationDate = Date().timeIntervalSinceReferenceDate
            }
            upload.managedObjectContext?.saveIfNeeded()
            
            // Launch preparation job according to file format
            let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
            
            // Chek that the image format is accepted by the Piwigo server
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                try await prepareImage(atURL: fileURL, for: upload)
                return true
            }
            
            // Convert image if JPEG format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                try await convertImage(atURL: fileURL, for: upload)
                return true
            }
            
            // Image file format cannot be accepted by the Piwigo server
            throw PwgKitError.unacceptedImageFormat
            
        case .video:
            // Get filename from asset
            let filename = getVideoFileName(from: originalAsset, for: upload)
            
            // Update upload request
            upload.fileType = pwgImageFileType.image.rawValue
            upload.fileName = filename
            upload.fileName = renamedFile(for: upload)         // Rename file if requested by user
            
            // Retrieve creation date from PHAsset (local time, or UTC time if time zone provided)
            if let creationDate = originalAsset.creationDate {
                upload.creationDate = creationDate.timeIntervalSinceReferenceDate
            } else {
                upload.creationDate = Date().timeIntervalSinceReferenceDate
            }
            upload.managedObjectContext?.saveIfNeeded()
            
            // Launch preparation job according to file format
            let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
            
            // File name of final video data to be stored into Piwigo/Uploads directory
            let outputURL = getUploadFileURL(from: upload.localIdentifier,
                                             creationDate: upload.creationDate)
            
            // Chek that the video format is accepted by the Piwigo server
            /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
            if NetworkVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                prepareVideo(ofAsset: originalAsset, atURL: outputURL, for: upload)
                return false
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if NetworkVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
                convertVideo(ofAsset: originalAsset, atURL: outputURL, for: upload)
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
    /// -> return updated upload properties w/ or w/o error
    func setMD5sumAndMIMEtype(ofUpload upload: Upload, forFileAtURL originalFileURL: URL) throws(PwgKitError) {
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().lastPathComponent) • Set MD5 checskum and MIME type")
        
        // File name of image data to be stored into Piwigo/Uploads directory
        let fileURL = getUploadFileURL(from: upload.localIdentifier, creationDate: upload.creationDate)
        
        // Should we rename the file to adopt the Upload Manager convention?
        if originalFileURL != fileURL {
            // Deletes temporary Upload file if it exists (incomplete previous attempt?)
            try? FileManager.default.removeItem(at: fileURL)

            // Adopts Upload filename convention (e.g. removes "-original" suffix or copies original file)
            do {
                if originalFileURL.deletingLastPathComponent() == DataDirectories.appUploadsDirectory {
                    try FileManager.default.moveItem(at: originalFileURL, to: fileURL)
                } else {
                    try FileManager.default.copyItem(at: originalFileURL, to: fileURL)
                }
            }
            catch let error as CocoaError {
                // Update upload request state
                throw .fileOperationFailed(innerError: error)
            }
            catch {
                throw .otherError(innerError: error)
            }
        }
        
        // Set file creation date as the photo creation date
        let creationDate = NSDate(timeIntervalSinceReferenceDate: upload.creationDate)
        let attrs = [FileAttributeKey.creationDate     : creationDate,
                     FileAttributeKey.modificationDate : creationDate]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path)
        
        // Determine MD5 checksum of image file to upload
        let md5Sum = try fileURL.MD5checksum()
        
        // Get MIME type from file extension
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        guard let uti = UTType(filenameExtension: fileExt),
              let mimeType = uti.preferredMIMEType
        else {
            throw .missingAsset
        }

        // Update Upload
        upload.md5Sum = md5Sum
        upload.mimeType = mimeType
        upload.managedObjectContext?.saveIfNeeded()
    }
}
