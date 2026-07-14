//
//  UploadManager+Prepare.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 23/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import Foundation
import Photos
import PwgKit
import PwgCacheKit

@UploadManagerActor
extension UploadManager
{
    // MARK: - Prepare Image/Video    
    public func prepareUpload(withID uploadID: NSManagedObjectID,
                              inTaskType taskType: UploadTaskType) async -> Void {
        
        // Retrieve upload request properties
        guard var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext)
        else {
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Could not retrieve upload request for preparation!")
            // In foreground, process next upload if any
            if taskType.isForeground {
                await UploadManagerActor.shared.processNextUpload()
            }
            return
        }
        
        // Check upload status (should never happen)
        guard uploadData.requestState == .waiting
        else {
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Upload in wrong state '\(uploadData.stateLabel)' before preparation")
            // In foreground, process next upload if any
            if taskType.isForeground {
                if uploadData.requestState == .prepared {
                    await UploadManagerActor.shared.addUploadsToTransfer(withIDs: [uploadID])
                }
                else if uploadData.requestState == .uploaded {
                    await UploadManagerActor.shared.addUploadsToFinish(withIDs: [uploadID])
                }
                await UploadManagerActor.shared.processNextUpload()
            }
            return
        }
        
        // Update upload status
        uploadData.requestState = .preparing
        uploadData.requestError = ""
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Preparing the file…")
        try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        
        // Add category ID to list of recently used albums
        let userInfo = ["categoryId": uploadData.category]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
        
        // Update progress bar
        let localIdentifier = uploadData.localIdentifier
        DispatchQueue.main.async {
            let uploadInfo: [String : Any] = ["localIdentifier" : localIdentifier,
                                              "progressFraction" : 0.0]
            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
        }
        
        // Determine from where the file comes from:
        /// => Photo Library: use PHAsset local identifier
        /// => UIPasteborad: use identifier of type "pwgClipboard-yyyyMMdd-HHmmssSSSS-typ-#", see kClipboardPrefix
        /// => ShareExtension: use identifier of type "pwgShared-yyyyMMdd-HHmmssSSSS-typ-#", see kSharedPrefix
        /// => Intent: use identifier of type "pwgIntent-yyyyMMdd-HHmmssSSSS-typ-#", see kIntentPrefix
        /// where "typ" is the type of the file to upload (see kImageSuffix, kMovieSuffix )
        /// and "#" is the index of the file
        do {
            if uploadData.localIdentifier.hasPrefix(kIntentPrefix) {
                // Case of an image submitted by the shortcut
                try await prepareImageFromFile(withPrefix: kIntentPrefix, for: &uploadData)
            }
            else if uploadData.localIdentifier.hasPrefix(kClipboardPrefix) {
                // Case of an image retrieved from the pasteboard
                try await prepareImageFromFile(withPrefix: kClipboardPrefix, for: &uploadData)
            }
            else if uploadData.localIdentifier.hasPrefix(kSharedPrefix) {
                // Case of an image retrieved from the pasteboard
                try await prepareImageFromFile(withPrefix: kSharedPrefix, for: &uploadData)
            }
            else {
                // Case of an image from the local Photo Library
                if try await prepareAssetInPhotoLibrary(for: &uploadData, withID: uploadID, inTaskType: taskType) == false {
                    // Stop job here for videos
                    return
                }
            }
            
            // Preparation completed
            uploadData.requestState = .prepared
            uploadData.requestError = ""
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            
            // Launch transfer if called by active background task
            if taskType.isBackgroundAndActive {
                await transferOrCopyFileOfUpload(withID: uploadID, inTaskType: taskType)
            }
            else { // Add upload to transfer queue
                await UploadManagerActor.shared.addUploadsToTransfer(withIDs: [uploadID])
            }
        }
        catch let error {
            switch error {
            case .unacceptedImageFormat, .unacceptedVideoFormat, .unacceptedAudioFormat, .unacceptedDataFormat:
                uploadData.requestState = .formatError
                uploadData.requestError = error.localizedDescription
                try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            case .cannotStripPrivateMetadata, .videoEncodingError:
                uploadData.requestState = .preparingError
                uploadData.requestError = error.localizedDescription
                try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            case .missingAsset, .otherError:
                fallthrough
            default:
                uploadData.requestState = .preparingFail
                uploadData.requestError = error.localizedDescription
                try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
            }
        }
        
        // In foreground, process next upload if any
        if taskType.isForeground {
            await UploadManagerActor.shared.processNextUpload()
        }
    }
    
    fileprivate func prepareImageFromFile(withPrefix prefix: String, for uploadData: inout UploadProperties) async throws(PwgKitError)
    {
        // Get prefixed files in the Uploads directory
        var files = [URL]()
        do {
            files = try FileManager.default.contentsOfDirectory(at: DataDirectories.appUploadsDirectory,
                                                                includingPropertiesForKeys: nil,
                                                                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            files.removeAll(where: { $0.lastPathComponent.hasPrefix(prefix) == false })
        }
        catch {
            throw .missingAsset
        }
        
        // Get file URL from identifier
        // NB: Media files are stored under their exact identifier (no extension), so match the name exactly.
        guard let fileURL = files.first(where: { $0.lastPathComponent == uploadData.localIdentifier })
        else {
            // File not available… deleted?
            throw .missingAsset
        }
        
        // Get file extension from file name already stored in upload data
        let fileExt = URL(fileURLWithPath: uploadData.fileName).pathExtension.lowercased()
        
        // Launch preparation job if file format accepted by Piwigo server
        if uploadData.localIdentifier.contains(kImageSuffix) {
            // Set file type
            uploadData.fileType = pwgImageFileType.image.rawValue
            
            // Chek that the image format is accepted by the Piwigo server
            if ServerVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                try await prepareImage(atURL: fileURL, for: &uploadData)
                return
            }
            
            // Try to convert image if JPEG format is accepted by Piwigo server
            if ServerVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                try await convertImage(atURL: fileURL, for: &uploadData)
                return
            }
            
            // Image file format cannot be accepted by the Piwigo server
            throw .unacceptedImageFormat
        }
        else if uploadData.localIdentifier.contains(kMovieSuffix) {
            // Set file type
            uploadData.fileType = pwgImageFileType.video.rawValue
            
            // Chek that the video format is accepted by the Piwigo server
            if ServerVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                try await prepareVideo(atURL: fileURL, for: &uploadData)
                return
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if ServerVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
                try await convertVideo(atURL: fileURL, for: &uploadData)
                return
            }
            
            // Video file format cannot be accepted by the Piwigo server
            throw .unacceptedVideoFormat
        }
        else if uploadData.localIdentifier.contains(kPdfSuffix) {
            // Set file type
            uploadData.fileType = pwgImageFileType.pdf.rawValue

            // Check that the PDF format is accepted by the Piwigo server
            if ServerVars.shared.serverFileTypes.contains("pdf") {
                // Upload the PDF file as is (image modifications do not apply)
                uploadData.creationDate = (fileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate

                // Rename file according to user's demand from date/time/counter/etc.
                renamedFile(for: &uploadData)

                // Get MD5 checksum and MIME type, update counter
                try setMD5sumAndMIMEtype(using: &uploadData, forFileAtURL: fileURL)
                return
            }

            // PDF file format cannot be accepted by the Piwigo server
            throw .unacceptedDataFormat
        }
        else {
            // Unknown type
            throw .unacceptedDataFormat
        }
    }
    
    /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
    /// so we use old method with completion handler and return false in that case.
    fileprivate func prepareAssetInPhotoLibrary(for uploadData: inout UploadProperties,
                                                withID uploadID: NSManagedObjectID,
                                                inTaskType taskType: UploadTaskType) async throws(PwgKitError) -> Bool
    {
        // Retrieve image asset
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [uploadData.localIdentifier], options: nil)
        guard assets.count > 0, let originalAsset = assets.firstObject
        else { throw .missingAsset }
        
        // Get URL of image file to be stored into Piwigo/Uploads directory
        // and deletes temporary image file if exists (incomplete previous attempt?)
        let fileURL = getUploadFileURL(from: uploadData.localIdentifier, withSuffix: kOriginalSuffix,
                                       creationDate: uploadData.creationDate, deleted: true)
        
        // Preparation method depends on media type
        switch originalAsset.mediaType {
        case .image:
            // Create file from asset and get filename
            let filename = try await writePhotoFromAsset(originalAsset, toFile: fileURL)
            
            // Update upload request
            uploadData.fileType = pwgImageFileType.image.rawValue
            uploadData.fileName = filename
            
            // Launch preparation job according to file format
            let fileExt = (URL(fileURLWithPath: filename).pathExtension).lowercased()
            
            // Chek that the image format is accepted by the Piwigo server
            if ServerVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                try await prepareImage(atURL: fileURL, for: &uploadData)
                return true
            }
            
            // Convert image if JPEG format is accepted by Piwigo server
            if ServerVars.shared.serverFileTypes.contains("jpg"),
               acceptedImageExtensions.contains(fileExt) {
                // Try conversion to JPEG
                try await convertImage(atURL: fileURL, for: &uploadData)
                return true
            }
            
            // Image file format cannot be accepted by the Piwigo server
            throw PwgKitError.unacceptedImageFormat
            
        case .video:
            // Get filename from asset
            let filename = getVideoFileName(from: originalAsset)
            
            // Update upload request
            uploadData.fileType = pwgImageFileType.image.rawValue
            uploadData.fileName = filename
            
            // Launch preparation job according to file format
            let fileExt = (URL(fileURLWithPath: filename).pathExtension).lowercased()
            
            // File name of final video data to be stored into Piwigo/Uploads directory
            let outputURL = getUploadFileURL(from: uploadData.localIdentifier,
                                             creationDate: uploadData.creationDate)
            
            // Chek that the video format is accepted by the Piwigo server
            /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
            if ServerVars.shared.serverFileTypes.contains(fileExt) {
                // Launch preparation job
                prepareVideo(ofAsset: originalAsset, atURL: outputURL, for: uploadData, withID: uploadID, inTaskType: taskType)
                return false
            }
            
            // Convert video if MP4 format is accepted by Piwigo server
            if ServerVars.shared.serverFileTypes.contains("mp4"),
               acceptedMovieExtensions.contains(fileExt) {
                // Try conversion to MP4
                convertVideo(ofAsset: originalAsset, atURL: outputURL, for: uploadData, withID: uploadID, inTaskType: taskType)
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
    
    // Rename file according to user's demand from date/time/counter/etc.
    func renamedFile(for uploadData: inout UploadProperties) {
        // Anything to do?
        var fileName = uploadData.fileName
        if uploadData.fileNamePrefixEncodedActions.isEmpty,
           uploadData.fileNameReplaceEncodedActions.isEmpty,
           uploadData.fileNameSuffixEncodedActions.isEmpty,
           FileExtCase(rawValue: uploadData.fileNameExtensionCase) == .keep {
            // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
            uploadData.fileName = fileName.utf8mb3Encoded
            return
        }
        
        // Get album current counter value
        var currentCounter = UploadVars.shared.categoryCounterInit
        if let userURI = URL(string: uploadData.userURIstr),
            let userID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI),
            let user = try? uploadBckgContext.existingObject(with: userID) as? User,
            let album = try? AlbumProvider().getAlbum(ofUser: user, withId: uploadData.category) {
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
        let prefixActions = uploadData.fileNamePrefixEncodedActions.actions
        let replaceActions = uploadData.fileNameReplaceEncodedActions.actions
        let suffixActions = uploadData.fileNameSuffixEncodedActions.actions
        let caseOfExtension = FileExtCase(rawValue: uploadData.fileNameExtensionCase) ?? .keep
        let creationDate = Date(timeIntervalSinceReferenceDate: uploadData.creationDate)
        fileName.renameFile(prefixActions: prefixActions,
                            replaceActions: replaceActions,
                            suffixActions: suffixActions,
                            caseOfExtension: caseOfExtension,
                            albumID: uploadData.category,
                            date: creationDate,
                            counter: currentCounter)
        
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        uploadData.fileName = fileName.utf8mb3Encoded
    }
    
    /// - Rename Upload file if needed
    /// - Get MD5 checksum and MIME type
    /// -> return updated upload properties w/ or w/o error
    func setMD5sumAndMIMEtype(using uploadData: inout UploadProperties,
                              forFileAtURL originalFileURL: URL) throws(PwgKitError)
    {
        // File name of image data to be stored into Piwigo/Uploads directory
        let fileURL = getUploadFileURL(from: uploadData.localIdentifier, creationDate: uploadData.creationDate)
        
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
        let creationDate = NSDate(timeIntervalSinceReferenceDate: uploadData.creationDate)
        let attrs = [FileAttributeKey.creationDate     : creationDate,
                     FileAttributeKey.modificationDate : creationDate]
        try? FileManager.default.setAttributes(attrs, ofItemAtPath: fileURL.path)
        
        // Determine MD5 checksum of image file to upload
        uploadData.md5Sum = try fileURL.MD5checksum()
        
        // Get MIME type from file extension
        let fileExt = (URL(fileURLWithPath: uploadData.fileName).pathExtension).lowercased()
        guard let uti = UTType(filenameExtension: fileExt),
              let mimeType = uti.preferredMIMEType
        else {
            throw .missingAsset
        }
        uploadData.mimeType = mimeType
    }
}
