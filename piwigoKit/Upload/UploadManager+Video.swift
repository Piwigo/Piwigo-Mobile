//
//  UploadVideo.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import CoreData

extension UploadManager {
    
    // MARK: - Prepare Video From Pasteboard
    // Case of a video from the Pasteboard which is in a format accepted by the Piwigo server
    func prepareVideo(atURL originalFileURL: URL, for upload: Upload) -> Void {
        autoreleasepool {
            // Retrieve video data
            let originalVideo = AVAsset(url: originalFileURL)

            // Check if the user wants to:
            /// - reduce the frame size
            /// - remove the private metadata
            if (upload.resizeImageOnUpload && upload.videoMaxSize != 0) ||
                (upload.stripGPSdataOnUpload && originalVideo.metadata.containsPrivateMetadata()) {
                // Check that the video can be exported
                self.checkVideoExportability(of: originalVideo, for: upload)
                return
            }
            
            // Get MD5 checksum and MIME type, update counter
            finalizeImageFile(atURL: originalFileURL, with: upload) {
                self.didPrepareVideo(for: upload, nil)
            } failure: { error in
                self.didPrepareVideo(for: upload, error)
            }
        }
    }

    // Case of a video from the Pasteboard which is in a format not accepted by the Piwigo server
    func convertVideo(atURL originalFileURL: URL, for upload: Upload) -> Void {

        // Retrieve video data
        let originalVideo = AVAsset(url: originalFileURL)

        // Check that the video can be exported
        checkVideoExportability(of: originalVideo, for: upload)
    }

    
    // MARK: - Prepare Video From Photo Library
    // Case of a video from the Photo Library which is in a format accepted by the Piwigo server
    func prepareVideo(ofAsset imageAsset: PHAsset, for upload: Upload) -> Void {

        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { (avasset, options, error) in
            // Error?
            if let error = error {
                self.didPrepareVideo(for: upload, error)
                return
            }

            // Valid AVAsset?
            guard let originalVideo = avasset else {
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: upload, error)
                return
            }
            
            // Check if the user wants to:
            /// - reduce the frame size
            /// - remove the private metadata
            if (upload.resizeImageOnUpload && upload.videoMaxSize != 0) ||
                (upload.stripGPSdataOnUpload && originalVideo.metadata.containsPrivateMetadata()) {
                // Check that the video can be exported
                self.checkVideoExportability(of: originalVideo, for: upload)
                return
            }
            
            // Get original fileURL
            guard let originalFileURL = (originalVideo as? AVURLAsset)?.url else {
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: upload, error)
                return
            }

            // Get MIME type
            guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, originalFileURL.pathExtension as NSString, nil)?.takeRetainedValue() else {
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: upload, error)
                return
            }
            guard let mimeType = (UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()) as String? else  {
                let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: upload, error)
                return
            }
            upload.mimeType = mimeType

            // Prepare URL of temporary file
            let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
            let fileURL = self.applicationUploadsDirectory.appendingPathComponent(fileName)

            // Deletes temporary video file if it already exists
            try? FileManager.default.removeItem(at: fileURL)

            // Determine MD5 checksum
            let error: NSError?
            (upload.md5Sum, error) = originalFileURL.MD5checksum()
            print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: upload.md5Sum))")
            if error != nil {
                // Could not determine the MD5 checksum
                self.didPrepareVideo(for: upload, error)
                return
            }

            // Copy video file into Piwigo/Uploads directory
            do {
                try FileManager.default.copyItem(at: originalFileURL, to: fileURL)
                // Upload video with tags and properties
                self.countOfBytesPrepared += fileURL.fileSize
                self.didPrepareVideo(for: upload, nil)
                return
            }
            catch let error as NSError {
                // Could not copy the video file
                self.didPrepareVideo(for: upload, error)
            }
        }
    }
    
    // Case of a video from the Photo Library which is in a format not accepted by the Piwigo server
    func convertVideo(ofAsset imageAsset: PHAsset, for upload: Upload) -> Void {

        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { [unowned self] (avasset, options, error) in
            // Error?
            if let error = error {
                self.didPrepareVideo(for: upload, error)
                return
            }

            // Valid AVAsset?
            guard let originalVideo = avasset else {
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: upload, error)
                return
            }
            
            // Check that the video can be exported
            self.checkVideoExportability(of: originalVideo, for: upload)
        }
    }
    
    private func didPrepareVideo(for upload: Upload, _ error: Error?) {
        // Error?
        if let error = error {
            upload.setState(.preparingError, error: error)
            // Update UI
            updateCell(with: upload.localIdentifier, stateLabel: upload.stateLabel,
                       photoMaxSize: nil, progress: nil, errorMsg: error.localizedDescription)
        } else {
            upload.setState(.prepared, error: nil)
        }

        // Upload ready for transfer
        self.backgroundQueue.async {
            self.didEndPreparation()
        }
    }

    
    // MARK: - Retrieve Video
    /// Used to retrieve video data from the PhotoLibrary
    private func getVideoRequestOptions() -> PHVideoRequestOptions {
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
    
    private func retrieveVideo(from imageAsset: PHAsset, with options: PHVideoRequestOptions,
                       completionHandler: @escaping (AVAsset?, PHVideoRequestOptions, Error?) -> Void) {
        print("\(debugFormatter.string(from: Date())) > enters retrieveVideoAssetFrom in", queueName())

        // The block Photos calls periodically while downloading the video.
        options.progressHandler = { progress, error, stop, dict in
        #if DEBUG_UPLOAD
            print(String(format: "downloading Video — progress %lf", progress))
        #endif
            // The handler needs to update the user interface => Dispatch to main thread
//            DispatchQueue.main.async(execute: {
//                self.iCloudProgress = progress
//                let imageBeingUploaded = self.imageUploadQueue.first as? ImageUpload
//                if error != nil {
//                    // Inform user and propose to cancel or continue
//                    self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_iCloud", comment: "Could not retrieve video. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
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
//                        print(String(format: "retrieveFullSizeAssetDataFromVideo: %.2f", progress))
//                        self.delegate.imageProgress(image, onCurrent: self.current, forTotal: self.total, onChunk: self.currentChunk, forChunks: self.totalChunks, iCloudProgress: progress)
//                    }
//                }
//            })
        }

        // Available export session presets?
        PHImageManager.default().requestAVAsset(forVideo: imageAsset,
                                                options: options,
                                                resultHandler: { [unowned self] avasset, audioMix, info in
            // ====>> For debugging…
//            if let metadata = avasset?.metadata {
//                print("=> Metadata: \(metadata)")
//            }
//            if let creationDate = avasset?.creationDate {
//                print("=> Creation date: \(creationDate)")
//            }
//            print("=> Exportable: \(avasset?.isExportable ?? false ? "Yes" : "No")")
//            if let avasset = avasset {
//                print("=> Compatibility: \(AVAssetExportSession.exportPresets(compatibleWith: avasset))")
//            }
//            if let tracks = avasset?.tracks {
//                print("=> Tracks: \(tracks)")
//            }
//            for track in avasset?.tracks ?? [] {
//                if track.mediaType == .video {
//                    print(String(format: "=>       : %.f x %.f", track.naturalSize.width, track.naturalSize.height))
//                }
//                var format = ""
//                for i in 0..<track.formatDescriptions.count {
//                    let desc = (track.formatDescriptions[i]) as! CMFormatDescription
//                    // Get String representation of media type (vide, soun, sbtl, etc.)
//                    var type: String? = nil
//                    type = self.FourCCString(CMFormatDescriptionGetMediaType(desc))
//                    // Get String representation media subtype (avc1, aac, tx3g, etc.)
//                    var subType: String? = nil
//                    subType = self.FourCCString(CMFormatDescriptionGetMediaSubType(desc))
//                    // Format string as type/subType
//                    format.append(contentsOf: "\(type ?? "")/\(subType ?? "")")
//                    // Comma separate if more than one format description
//                    if i < track.formatDescriptions.count - 1 {
//                        format.append(contentsOf: ",")
//                    }
//                }
//                print("=>       : \(format)")
//            }
            // <<==== End of code for debugging
            
            // resultHandler performed on another thread!
            if self.isExecutingBackgroundUploadTask {
//                print("\(self.debugFormatter.string(from: Date())) > exits retrieveVideoAssetFrom in", queueName())
                // Any error?
                if info?[PHImageErrorKey] != nil {
                    completionHandler(nil, options, info?[PHImageErrorKey] as? Error)
                    return
                }
                completionHandler(avasset, options, nil)
            } else {
                self.backgroundQueue.async {
//                    print("\(self.debugFormatter.string(from: Date())) > exits retrieveVideoAssetFrom in", queueName())
                    // Any error?
                    if info?[PHImageErrorKey] != nil {
                        completionHandler(nil, options, info?[PHImageErrorKey] as? Error)
                        return
                    }
                    completionHandler(avasset, options, nil)
                }
            }
        })
    }
                             
    
    // MARK: - Export Video
    /// - Determine video size and reduce it if requested
    private func checkVideoExportability(of originalVideo: AVAsset, for upload: Upload) {
        // We cannot convert the video if it is not exportable
        if !originalVideo.isExportable {
            let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("shareMetadataError_message", comment: "Cannot strip private metadata")])
            didPrepareVideo(for: upload, error)
            return
        }
        else {
            // Determine optimal export options (highest quality for device by default)
            let exportPreset = self.getExportPreset(for: originalVideo, and: upload)

            // Export new video in MP4 format w/ or w/o private metadata
            export(videoAsset: originalVideo, with: exportPreset, for: upload)
        }
    }
    
    private func getExportPreset(for videoAsset: AVAsset, and upload: Upload) -> String {
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
        return exportPreset
    }
    
    private func export(videoAsset: AVAsset, with exportPreset:String, for upload: Upload) {
        autoreleasepool {
            // Get export session
            guard let exportSession = AVAssetExportSession(asset: videoAsset,
                                                           presetName: exportPreset) else {
                let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                didPrepareVideo(for: upload, error)
                return
            }
            
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
    //        print("===>> Common Metadata: \(commonMetadata)")
    //
    //        let allMetadata = videoAsset.metadata
    //        print("===>> All Metadata: \(allMetadata)")
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
    //        print("===>> new Metadata: \(newMetadata)")
    //        exportSession.metadata = newMetadata

            // Prepare MIME type
            upload.mimeType = "video/mp4"
            upload.fileName = URL(fileURLWithPath: upload.fileName)
                .deletingPathExtension().appendingPathExtension("MP4").lastPathComponent

            // File name of final video data to be stored into Piwigo/Uploads directory
            exportSession.outputURL = getUploadFileURL(from: upload, deleted: true)

            // Export temporary video for upload
            exportSession.exportAsynchronously { [unowned self] in
                guard exportSession.status == .completed,
                      let outputURL = exportSession.outputURL else {
                    // Deletes temporary video file if any
                    do {
                        try FileManager.default.removeItem(at: exportSession.outputURL!)
                    } catch {
                    }
                    // Report error
                    let error = NSError(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                    self.didPrepareVideo(for: upload, error)
                    return
                }

                // Get MD5 checksum and MIME type, update counter
                self.finalizeImageFile(atURL: outputURL, with: upload) {
                    // Update upload request
                    self.didPrepareVideo(for: upload, nil)
                } failure: { error in
                    self.didPrepareVideo(for: upload, error)
                }
            }
        }
    }
}
