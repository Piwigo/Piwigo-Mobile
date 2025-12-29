//
//  UploadManager+PrepareVideo.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import CoreData
@preconcurrency import piwigoKit

extension UploadManager {
    
    // MARK: - Prepare Video From File
    // Case of a video which is in a format accepted by the Piwigo server
    func prepareVideo(atURL originalFileURL: URL, for upload: Upload) async throws(PwgKitError) {
        // Retrieve video data
        let originalVideo = AVAsset(url: originalFileURL)
        
        // Get creation date from metadata if possible
        let metadata = originalVideo.metadata
        if let dateFromMetadata = metadata.creationDate() {
            upload.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
        } else {
            upload.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }
        
        // Check if the user wants to:
        /// - reduce the frame size
        /// - remove the private metadata
        if (upload.resizeImageOnUpload && upload.videoMaxSize != 0) ||
            (upload.stripGPSdataOnUpload && originalVideo.metadata.containsPrivateMetadata()) {
            // Check that the video can be exported
            try await checkVideoExportability(of: originalVideo)
            
            // File name of final video data to be stored into Piwigo/Uploads directory
            let outputURL = getUploadFileURL(from: upload, deleted: false)

            // Export new video in MP4 format w/ or w/o private metadata
            let convertedVideoURL = try await export(videoAsset: originalVideo, to: outputURL, for: upload)
            
            // Get MD5 checksum and MIME type, update counter
            try finalizeImageFile(atURL: convertedVideoURL, with: upload)
        }
        else {
            // Get MD5 checksum and MIME type, update counter
            try finalizeImageFile(atURL: originalFileURL, with: upload)
        }
    }
    
    // Case of a video which is in a format not accepted by the Piwigo server
    func convertVideo(atURL originalFileURL: URL, for upload: Upload) async throws(PwgKitError) {
        
        // Retrieve video data
        let originalVideo = AVAsset(url: originalFileURL)
        
        // Get creation date from metadata if possible
        let metadata = originalVideo.metadata
        if let dateFromMetadata = metadata.creationDate() {
            upload.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
        } else {
            upload.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }
        
        // Check that the video can be exported
        try await checkVideoExportability(of: originalVideo)
        
        // File name of final video data to be stored into Piwigo/Uploads directory
        let outputURL = getUploadFileURL(from: upload, deleted: false)

        // Export new video in MP4 format w/ or w/o private metadata
        let convertedVideoURL = try await export(videoAsset: originalVideo, to: outputURL, for: upload)
        
        // Get MD5 checksum and MIME type, update counter
        try finalizeImageFile(atURL: convertedVideoURL, with: upload)
    }
    
    // Check the exportability of a video (modern version)
    private func checkVideoExportability(of originalVideo: AVAsset) async throws(PwgKitError) {
        // Check that the video can be exported
        do {
            let isExportable = try await originalVideo.load(.isExportable)
            if isExportable == false { throw AVError(.encoderNotFound) }
        }
        catch let error as AVError {
            throw .videoEncodingError(innerError: error)
        }
        catch {
            throw .otherError(innerError: error)
        }
    }
        
    // Export a video in MP4 format w/ or w/o private metadata
    private func export(videoAsset: AVAsset, to outputURL: URL, for upload: Upload) async throws(PwgKitError) -> URL {

        // Determine available export options (highest quality for device by default)
        let presets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)
        
        // Produce QuickTime movie file with video size appropriate to the current device by default
        /// - The export will not scale the video up from a smaller size.
        /// - Compression for video uses H.264; compression for audio uses AAC.
        var exportPreset = AVAssetExportPresetHighestQuality
        
        // Determine video size
        let videoSize = videoAsset.tracks(withMediaType: .video).first?.naturalSize ?? CGSize(width: 640, height: 480)
        var maxPixels = Int(max(videoSize.width, videoSize.height))
        
        // Resize frames
        if upload.resizeImageOnUpload, upload.videoMaxSize != 0 {
            maxPixels = pwgVideoMaxSizes(rawValue: upload.videoMaxSize)?.pixels ?? Int.max
        }
        
        // The 'presets' array never contains AVAssetExportPresetPassthrough,
        if (maxPixels <= 640) && presets.contains(AVAssetExportPreset640x480) {
            // Encode in 640x480 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset640x480
        } else if (maxPixels <= 960) && presets.contains(AVAssetExportPreset960x540) {
            // Encode in 960x540 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset960x540
        } else if (maxPixels <= 1280) && presets.contains(AVAssetExportPreset1280x720) {
            // Encode in 1280x720 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset1280x720
        } else if (maxPixels <= 1920) && presets.contains(AVAssetExportPreset1920x1080) {
            // Encode in 1920x1080 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset1920x1080
        } else if (maxPixels <= 3840) && presets.contains(AVAssetExportPreset1920x1080) {
            // Encode in 3840x2160 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset3840x2160
        }

        // Get export session
        guard let exportSession = AVAssetExportSession(asset: videoAsset,
                                                       presetName: exportPreset)
        else { throw .missingAsset }
        
        // Set parameters
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)
        
        // Strips private metadata if user requested it in Settings
        // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
        if upload.stripGPSdataOnUpload {
            exportSession.metadataItemFilter = AVMetadataItemFilter.forSharing()
        } else {
            exportSession.metadata = videoAsset.metadata
        }
        
//        let commonMetadata = videoAsset.commonMetadata
//        debugPrint("===>> Common Metadata: \(commonMetadata)")
//
//        let allMetadata = videoAsset.metadata
//        debugPrint("===>> All Metadata: \(allMetadata)")
//
//        let makeItem =  AVMutableMetadataItem()
//        makeItem.identifier = AVMetadataIdentifier.iTunesMetadataArtist
//        makeItem.keySpace = AVMetadataKeySpace.iTunes
//        makeItem.key = AVMetadataKey.iTunesMetadataKeyArtist as (any NSCopying & NSObjectProtocol)
//        makeItem.value = "Piwigo Artist" as (any NSCopying & NSObjectProtocol)
//
//        let anotherItem =  AVMutableMetadataItem()
//        anotherItem.identifier = AVMetadataIdentifier.iTunesMetadataAuthor
//        anotherItem.keySpace = AVMetadataKeySpace.iTunes
//        anotherItem.key = AVMetadataKey.iTunesMetadataKeyAuthor as (any NSCopying & NSObjectProtocol)
//        anotherItem.value = "Piwigo Author" as (any NSCopying & NSObjectProtocol)
//
//        var newMetadata = commonMetadata
//        newMetadata.append(makeItem)
//        newMetadata.append(anotherItem)
//        debugPrint("===>> new Metadata: \(newMetadata)")
//        exportSession.metadata = newMetadata
        
        // Prepare MIME type, file
        upload.mimeType = "video/mp4"
        upload.fileName = URL(fileURLWithPath: upload.fileName)
            .deletingPathExtension().appendingPathExtension("MP4").lastPathComponent
        
        exportSession.outputURL = outputURL
        do {
            // Export temporary video for upload
            try await exportSession.export(to: outputURL, as: .mp4)
            return outputURL
        }
        catch let error as AVError {
            // Deletes temporary video file if any
            try? FileManager.default.removeItem(at: exportSession.outputURL!)
            
            // Report error
            throw .videoEncodingError(innerError: error)
        }
        catch {
            // Deletes temporary video file if any
            try? FileManager.default.removeItem(at: exportSession.outputURL!)
            
            throw .otherError(innerError: error)
        }
    }
    
    
    // MARK: - Prepare Video From Photo Library Asset
    // Case of a video from the Photo Library which is in a format accepted by the Piwigo server
    /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
    nonisolated func prepareVideo(ofAsset imageAsset: PHAsset, atURL outputURL: URL, for upload: Upload) -> Void {
        
        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { (avasset, error) in
            // Error?
            if let error = error {
                Task { @UploadManagerActor in
                    self.didPrepareVideo(for: upload, error)
                }
                return
            }
            
            // Valid AVAsset?
            guard let originalVideo = avasset else {
                Task { @UploadManagerActor in
                    self.didPrepareVideo(for: upload, .missingAsset)
                }
                return
            }
            
            // Get original fileURL
            guard let originalFileURL = (originalVideo as? AVURLAsset)?.url else {
                Task { @UploadManagerActor in
                    self.didPrepareVideo(for: upload, .missingAsset)
                }
                return
            }
            
            // Get creation date from metadata if possible
            let metadata = originalVideo.metadata
            if let dateFromMetadata = metadata.creationDate() {
                upload.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
            } else {
                upload.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
            }
            
            // Check if the user wants to:
            /// - reduce the frame size
            /// - remove the private metadata
            if (upload.resizeImageOnUpload && upload.videoMaxSize != 0) ||
                (upload.stripGPSdataOnUpload && originalVideo.metadata.containsPrivateMetadata()) {
                // Check that the video can be exported
                guard originalVideo.isExportable else {
                    Task { @UploadManagerActor in
                        self.didPrepareVideo(for: upload, .cannotStripPrivateMetadata)
                    }
                    return
                }

                // Export new video in MP4 format w/ or w/o private metadata
                self.export(videoAsset: originalVideo, outputURL: outputURL, for: upload)
                return
            }
            
            // Get MIME type
            let fileExt = originalFileURL.pathExtension.lowercased()
            guard let uti = UTType(filenameExtension: fileExt),
                  let mimeType = uti.preferredMIMEType
            else {
                Task { @UploadManagerActor in
                    self.didPrepareVideo(for: upload, .missingAsset)
                }
                return
            }
            upload.mimeType = mimeType
            
            // Copy video file into Piwigo/Uploads directory
            do {
                // Determine MD5 checksum
                try upload.md5Sum = originalFileURL.MD5checksum()
                
                Task { @UploadManagerActor in
                    // Prepare URL of temporary file
                    let fileURL = self.getUploadFileURL(from: upload, deleted: true)
                    try FileManager.default.copyItem(at: originalFileURL, to: fileURL)
                    
                    // Upload video with tags and properties
                    self.countOfBytesPrepared += fileURL.fileSize
                    self.didPrepareVideo(for: upload, nil)
                }
                return
            }
            catch let error as CocoaError {
                Task { @UploadManagerActor in
                    self.didPrepareVideo(for: upload, .fileOperationFailed(innerError: error))
                }
            }
            catch {
                // Could not copy the video file
                Task { @UploadManagerActor in
                    self.didPrepareVideo(for: upload, .otherError(innerError: error))
                }
            }
        }
    }
    
    // Case of a video from the Photo Library which is in a format not accepted by the Piwigo server
    /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
    func convertVideo(ofAsset imageAsset: PHAsset, atURL outputURL: URL, for upload: Upload) -> Void {
        
        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { [self] (avasset, error) in
            // Error?
            if let error = error {
                self.didPrepareVideo(for: upload, error)
                return
            }
            
            // Valid AVAsset?
            guard let originalVideo = avasset else {
                self.didPrepareVideo(for: upload, .missingAsset)
                return
            }
            
            // Get original fileURL
            guard let originalFileURL = (originalVideo as? AVURLAsset)?.url else {
                self.didPrepareVideo(for: upload, .missingAsset)
                return
            }
            
            // Get creation date from metadata if possible
            let metadata = originalVideo.metadata
            if let dateFromMetadata = metadata.creationDate() {
                upload.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
            } else {
                upload.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
            }
            
            // Check that the video can be exported
            guard originalVideo.isExportable else {
                self.didPrepareVideo(for: upload, .unacceptedVideoFormat)
                return
            }
            
            // Export new video in MP4 format w/ or w/o private metadata
            self.export(videoAsset: originalVideo, outputURL: outputURL, for: upload)
        }
    }
    
    private func didPrepareVideo(for upload: Upload, _ error: PwgKitError?) {
        Task { @UploadManagerActor in
            // Upload ready for transfer
            // Error?
            if let error = error {
                upload.setState(.preparingError, error: error, save: false)
            } else {
                upload.setState(.prepared, save: false)
            }
            
            self.uploadBckgContext.saveIfNeeded()
            await self.didEndPreparation()
        }
    }
    
    
    // MARK: - Retrieve Video Asset
    /// Used to retrieve video data from the PhotoLibrary
    /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2
    func getVideoFileName(from originalAsset: PHAsset, for upload: Upload) {
        // Retrieve original filename from asset resources
        let resources = PHAssetResource.assetResources(for: originalAsset)
        let original = resources.first(where: { $0.type == .photo || $0.type == .video || $0.type == .audio })
        let originalFilename = original?.originalFilename ?? ""
        upload.fileName = getFilename(fromName: originalFilename, ofAsset: originalAsset)
    }
    
    private nonisolated func getVideoRequestOptions() -> PHVideoRequestOptions {
        // Case of a video…
        let options = PHVideoRequestOptions()
        // Requests the most recent version of the image asset
        options.version = PHVideoRequestOptionsVersion.current
        // Requests the highest-quality video available, regardless of how much time it takes to load.
        options.deliveryMode = .highQualityFormat
        // Photos can download the requested video from iCloud.
        options.isNetworkAccessAllowed = true
        
        return options
    }
    
    // Extract the AVAsset from the PHAsset
    // NB: Not possible to extract the AVAsset with async/await method as of iOS 26.2
    nonisolated func retrieveVideo(from imageAsset: PHAsset, with options: PHVideoRequestOptions,
                                   completion: @escaping (AVAsset?, PwgKitError?) -> Void) {
        
        // The block Photos calls periodically while downloading the video.
        options.progressHandler = { progress, error, stop, dict in
            debugPrint(String(format: "downloading Video — progress %lf", progress))
            // The handler needs to update the user interface => Dispatch to main thread
            //            DispatchQueue.main.async(execute: {
            //                self.iCloudProgress = progress
            //                let imageBeingUploaded = self.imageUploadQueue.first as? ImageUpload
            //                if error != nil {
            //                    // Inform user and propose to cancel or continue
            //                    self.showError(withTitle: "Video Upload Error",
            //                                   andMessage: error?.localizedDescription, forRetrying: true, withImage: image)
            //                    return
            //                } else if imageBeingUploaded?.stopUpload != nil {
            //                    // User wants to cancel the download
            //                    stop = UnsafeMutablePointer<ObjCBool>(mutating: &true)
            //
            //                    // Remove image from queue and upload next one
            //                    self.maximumImagesForBatch -= 1
            //                    self.uploadNextImageAndRemoveImage(fromQueue: image, withResponse: nil)
            //                } else {
            //                    // Updates progress bar(s)
            //                    if self.delegate.responds(to: #selector(imageProgress(_:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:))) {
            //                        debugPrint(String(format: "retrieveFullSizeAssetDataFromVideo: %.2f", progress))
            //                        self.delegate.imageProgress(image, onCurrent: self.current, forTotal: self.total, onChunk: self.currentChunk, forChunks: self.totalChunks, iCloudProgress: progress)
            //                    }
            //                }
            //            })
        }
        
        // Request AVAsset
        PHImageManager.default().requestAVAsset(forVideo: imageAsset,
                                                options: options,
                                                resultHandler: { avasset, _, info in
// ====>> For debugging…
            if let metadata = avasset?.metadata {
                debugPrint("=> Metadata: \(metadata)\r=> Creation date: \(metadata.creationDate() ?? DateUtilities.unknownDate)")
            }
            if let creationDate = avasset?.creationDate {
                debugPrint("=> Creation date: \(creationDate)")
            }
            debugPrint("=> Exportable: \(avasset?.isExportable ?? false ? "Yes" : "No")")
            if let avasset = avasset {
                debugPrint("=> Compatibility: \(AVAssetExportSession.exportPresets(compatibleWith: avasset))")
            }
            if let tracks = avasset?.tracks {
                debugPrint("=> Tracks: \(tracks)")
            }
            for track in avasset?.tracks ?? [] {
                if track.mediaType == .video {
                    debugPrint(String(format: "=>       : %.f x %.f", track.naturalSize.width, track.naturalSize.height))
                }
                var format = ""
                for i in 0..<track.formatDescriptions.count {
                    let desc = (track.formatDescriptions[i]) as! CMFormatDescription
                    // Get String representation of media type (vide, soun, sbtl, etc.)
                    var type: String? = nil
                    type = CMFormatDescriptionGetMediaType(desc).toString()
                    // Get String representation media subtype (avc1, aac, tx3g, etc.)
                    var subType: String? = nil
                    subType = CMFormatDescriptionGetMediaSubType(desc).toString()
                    // Format string as type/subType
                    format.append(contentsOf: "\(type ?? "")/\(subType ?? "")")
                    // Comma separate if more than one format description
                    if i < track.formatDescriptions.count - 1 {
                        format.append(contentsOf: ",")
                    }
                }
                debugPrint("=>       : \(format)")
            }
// <<==== End of code for debugging
            
            // resultHandler performed on another thread!
            // Any error?
            if let error = info?[PHImageErrorKey] as? (any Error) {
                if let photosError = error as? PHPhotosError {
                    completion(nil, PwgKitError.photoError(innerError: photosError))
                } else {
                    completion(nil, PwgKitError.otherError(innerError: error))
                }
            } else {
                completion(avasset, nil)
            }
        })
    }
    
    
    // MARK: - Export Video
    // Determine video size and reduce it if requested
    /// NB: Not possible to extract AVAsset with async/await methods as of iOS 26.2    
    private nonisolated func export(videoAsset: AVAsset, outputURL: URL, for upload: Upload) {
        autoreleasepool {
            // Determine available export options (highest quality for device by default)
            let presets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)
            
            // Produce QuickTime movie file with video size appropriate to the current device by default
            /// - The export will not scale the video up from a smaller size.
            /// - Compression for video uses H.264; compression for audio uses AAC.
            var exportPreset = AVAssetExportPresetHighestQuality
            
            // Determine video size
            let videoSize = videoAsset.tracks(withMediaType: .video).first?.naturalSize ?? CGSize(width: 640, height: 480)
            var maxPixels = Int(max(videoSize.width, videoSize.height))
            
            // Resize frames
            if upload.resizeImageOnUpload, upload.videoMaxSize != 0 {
                maxPixels = pwgVideoMaxSizes(rawValue: upload.videoMaxSize)?.pixels ?? Int.max
            }
            
            // The 'presets' array never contains AVAssetExportPresetPassthrough,
            if (maxPixels <= 640) && presets.contains(AVAssetExportPreset640x480) {
                // Encode in 640x480 pixels — metadata will be lost
                exportPreset = AVAssetExportPreset640x480
            } else if (maxPixels <= 960) && presets.contains(AVAssetExportPreset960x540) {
                // Encode in 960x540 pixels — metadata will be lost
                exportPreset = AVAssetExportPreset960x540
            } else if (maxPixels <= 1280) && presets.contains(AVAssetExportPreset1280x720) {
                // Encode in 1280x720 pixels — metadata will be lost
                exportPreset = AVAssetExportPreset1280x720
            } else if (maxPixels <= 1920) && presets.contains(AVAssetExportPreset1920x1080) {
                // Encode in 1920x1080 pixels — metadata will be lost
                exportPreset = AVAssetExportPreset1920x1080
            } else if (maxPixels <= 3840) && presets.contains(AVAssetExportPreset1920x1080) {
                // Encode in 3840x2160 pixels — metadata will be lost
                exportPreset = AVAssetExportPreset3840x2160
            }

            // Get export session
            guard let exportSession = AVAssetExportSession(asset: videoAsset,
                                                           presetName: exportPreset)
            else {
                Task { @UploadManagerActor in
                    didPrepareVideo(for: upload, .missingAsset)
                }
                return
            }
            
            // Set parameters
            exportSession.outputFileType = .mp4
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)
            exportSession.outputURL = outputURL
            
            // Strips private metadata if user requested it in Settings
            // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
            if upload.stripGPSdataOnUpload {
                exportSession.metadataItemFilter = AVMetadataItemFilter.forSharing()
            } else {
                exportSession.metadata = videoAsset.metadata
            }

    //        let commonMetadata = videoAsset.commonMetadata
    //        debugPrint("===>> Common Metadata: \(commonMetadata)")
    //
    //        let allMetadata = videoAsset.metadata
    //        debugPrint("===>> All Metadata: \(allMetadata)")
    //
    //        let makeItem =  AVMutableMetadataItem()
    //        makeItem.identifier = AVMetadataIdentifier.iTunesMetadataArtist
    //        makeItem.keySpace = AVMetadataKeySpace.iTunes
    //        makeItem.key = AVMetadataKey.iTunesMetadataKeyArtist as NSCopying & NSObjectProtocol
    //        makeItem.value = "Piwigo Artist" as NSCopying & NSObjectProtocol
    //
    //        let anotherItem =  AVMutableMetadataItem()
    //        anotherItem.identifier = AVMetadataIdentifier.iTunesMetadataAuthor
    //        anotherItem.keySpace = AVMetadataKeySpace.iTunes
    //        anotherItem.key = AVMetadataKey.iTunesMetadataKeyAuthor as NSCopying & NSObjectProtocol
    //        anotherItem.value = "Piwigo Author" as NSCopying & NSObjectProtocol
    //
    //        var newMetadata = commonMetadata
    //        newMetadata.append(makeItem)
    //        newMetadata.append(anotherItem)
    //        debugPrint("===>> new Metadata: \(newMetadata)")
    //        exportSession.metadata = newMetadata

            // Update upload
            upload.mimeType = "video/mp4"
            upload.fileName = URL(fileURLWithPath: upload.fileName)
                .deletingPathExtension().appendingPathExtension("MP4").lastPathComponent

            // Export temporary video for upload
            exportSession.exportAsynchronously { [self] in
                guard exportSession.status == .completed,
                      let outputURL = exportSession.outputURL
                else {
                    // Deletes temporary video file if any
                    try? FileManager.default.removeItem(at: exportSession.outputURL!)

                    // Report error
                    Task { @UploadManagerActor in
                        self.didPrepareVideo(for: upload, .missingAsset)
                    }
                    return
                }

                Task { @UploadManagerActor in
                    do {
                        // Get MD5 checksum and MIME type, update counter
                        try self.finalizeImageFile(atURL: outputURL, with: upload)
                        
                        // Update upload request
                        self.didPrepareVideo(for: upload, nil)
                    }
                    catch let error as CocoaError {
                        self.didPrepareVideo(for: upload, PwgKitError.fileOperationFailed(innerError: error))
                    }
                    catch {
                        self.didPrepareVideo(for: upload, PwgKitError.otherError(innerError: error))
                    }
                }
            }
        }
    }
}
