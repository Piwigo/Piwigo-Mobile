//
//  UploadVideo.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos

extension UploadManager {
    
    // MARK: - Video preparation
    /// Case of a video from the Pasteboard which is in a format accepted by the Piwigo server
    func prepareVideo(atURL originalFileURL: URL,
                      for uploadID: NSManagedObjectID, with uploadProperties: UploadProperties) -> Void {
        
        // Retrieve video data
        let originalVideo = AVAsset.init(url: originalFileURL)

        // Get MIME type
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, originalFileURL.pathExtension as NSString, nil)?.takeRetainedValue() else {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
            return
        }
        guard let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() else  {
            let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
            return
        }
        var newUploadProperties = uploadProperties
        newUploadProperties.mimeType = mimeType as String

        // Determine if metadata contains private data
        let assetMetadata = originalVideo.commonMetadata
        let locationMetadata = AVMetadataItem.metadataItems(from: assetMetadata, filteredByIdentifier: .commonIdentifierLocation)

        // Upload original video if metadata matches user's choice
        if !uploadProperties.stripGPSdataOnUpload ||
            (uploadProperties.stripGPSdataOnUpload && (locationMetadata.count == 0)) {

            // Determine MD5 checksum
            var videoData: Data = Data()
            do {
                try videoData = NSData (contentsOf: originalFileURL) as Data
                
                // Determine MD5 checksum of video file to upload
                var md5Checksum: String? = ""
                if #available(iOS 13.0, *) {
                    #if canImport(CryptoKit)        // Requires iOS 13
                    md5Checksum = self.MD5(data: videoData)
                    #endif
                } else {
                    // Fallback on earlier versions
                    md5Checksum = self.oldMD5(data: videoData)
                }
                newUploadProperties.md5Sum = md5Checksum
                print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: md5Checksum))")

                // Upload video with tags and properties
                self.didPrepareVideo(for: uploadID, with: newUploadProperties, nil)
            }
            catch let error as NSError {
                // Could not determine the MD5 checksum
                self.didPrepareVideo(for: uploadID, with: newUploadProperties, error)
            }
        }
        else {
            // Determine optimal export options (highest quality for device by default)
            let exportPreset = self.getExportPreset(for: originalVideo)

            // Remove private metadata by exporting a new video in MP4 format
            self.export(videoAsset: originalVideo, with: exportPreset,
                        for: uploadID, with: newUploadProperties)
        }
    }

    /// Case of a video from the Pasteboard which is in a format not accepted by the Piwigo server
    func convertVideo(atURL originalFileURL: URL,
                      for uploadID: NSManagedObjectID, with uploadProperties: UploadProperties) -> Void {

        // Retrieve video data
        let originalVideo = AVAsset.init(url: originalFileURL)

        // Determine optimal export options (highest quality for device by default)
        let exportPreset = self.getExportPreset(for: originalVideo)

        // Remove private metadata by exporting a new video in MP4 format
        self.export(videoAsset: originalVideo, with: exportPreset,
                    for: uploadID, with: uploadProperties)
    }

    /// Case of a video from the Photo Library which is in a format accepted by the Piwigo server
    func prepareVideo(ofAsset imageAsset: PHAsset,
                      for uploadID: NSManagedObjectID, with uploadProperties: UploadProperties) -> Void {

        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { (avasset, options, error) in
            // Error?
            if let error = error {
                self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
                return
            }

            // Valid AVAsset?
            guard let originalVideo = avasset else {
                let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
                return
            }
            
            // Get original fileURL
            guard let originalFileURL = (originalVideo as? AVURLAsset)?.url else {
                let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
                return
            }

            // Get MIME type
            guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, originalFileURL.pathExtension as NSString, nil)?.takeRetainedValue() else {
                let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
                return
            }
            guard let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() else  {
                let error = NSError.init(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
                return
            }
            var newUploadProperties = uploadProperties
            newUploadProperties.mimeType = mimeType as String

            // Determine if metadata contains private data
            let assetMetadata = originalVideo.commonMetadata
            let locationMetadata = AVMetadataItem.metadataItems(from: assetMetadata, filteredByIdentifier: .commonIdentifierLocation)

            // Upload original video if metadata matches user's choice
            if !uploadProperties.stripGPSdataOnUpload ||
                (uploadProperties.stripGPSdataOnUpload && (locationMetadata.count == 0)) {

                // Prepare URL of temporary file
                let fileName = uploadProperties.localIdentifier.replacingOccurrences(of: "/", with: "-")
                let fileURL = self.applicationUploadsDirectory.appendingPathComponent(fileName)

                // Deletes temporary video file if it already exists
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                }

                // Determine MD5 checksum
                var videoData: Data = Data()
                do {
                    try videoData = NSData (contentsOf: originalFileURL) as Data
                    
                    // Determine MD5 checksum of video file to upload
                    var md5Checksum: String? = ""
                    if #available(iOS 13.0, *) {
                        #if canImport(CryptoKit)        // Requires iOS 13
                        md5Checksum = self.MD5(data: videoData)
                        #endif
                    } else {
                        // Fallback on earlier versions
                        md5Checksum = self.oldMD5(data: videoData)
                    }
                    newUploadProperties.md5Sum = md5Checksum
                    print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: md5Checksum))")

                    // Copy video into Piwigo/Uploads directory
                    do {
                        try FileManager.default.copyItem(at: originalFileURL, to: fileURL)
                        // Upload video with tags and properties
                        self.didPrepareVideo(for: uploadID, with: newUploadProperties, nil)
                        return
                    }
                    catch let error as NSError {
                        // Could not copy the video file
                        self.didPrepareVideo(for: uploadID, with: newUploadProperties, error)
                    }
                }
                catch let error as NSError {
                    // Could not determine the MD5 checksum
                    self.didPrepareVideo(for: uploadID, with: newUploadProperties, error)
                }
            }
            else {
                // Determine optimal export options (highest quality for device by default)
                let exportPreset = self.getExportPreset(for: originalVideo)

                // Remove private metadata by exporting a new video in MP4 format
                self.export(imageAsset: imageAsset, with: options, exportPreset: exportPreset,
                            for: uploadID, with: newUploadProperties)
            }
        }
    }
    
    /// Case of a video from the Photo Library which is in a format not accepted by the Piwigo server
    func convertVideo(ofAsset imageAsset: PHAsset,
                      for uploadID: NSManagedObjectID, with uploadProperties: UploadProperties) -> Void {

        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { (avasset, options, error) in
            // Error?
            if let error = error {
                self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
                return
            }

            // Valid AVAsset?
            guard let originalVideo = avasset else {
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: uploadID, with: uploadProperties, error)
                return
            }
            
            // Determine optimal export options (highest quality for device by default)
            let exportPreset = self.getExportPreset(for: originalVideo)

            // Convert video to MP4 format
            self.export(imageAsset: imageAsset, with: options, exportPreset: exportPreset,
                        for: uploadID, with: uploadProperties)
        }
    }
    
    private func didPrepareVideo(for uploadID: NSManagedObjectID,
                                 with properties: UploadProperties, _ error: Error?) {
        // Initialisation
        var newProperties = properties
        newProperties.requestState = .prepared
        var errorMsg = ""
        
        // Error?
        if let error = error {
            newProperties.requestState = .preparingError
            errorMsg = error.localizedDescription
        }

        // Update UI
        updateCell(with: newProperties.localIdentifier, stateLabel: newProperties.stateLabel,
                   photoResize: nil, progress: Float(0.0), errorMsg: errorMsg)

        // Update state of upload request
        print("\(debugFormatter.string(from: Date())) > prepared \(uploadID) \(errorMsg)")
        uploadsProvider.updatePropertiesOfUpload(with: uploadID, properties: newProperties) { [unowned self] (_) in
            // Upload ready for transfer
            if self.isExecutingBackgroundUploadTask {
                // In background task
                if newProperties.requestState == .prepared {
                    self.transferInBackgroundImage(for: uploadID, with: newProperties)
                }
            } else {
                // Consider next step
                self.didEndPreparation()
            }
        }
    }

    
    // MARK: - Retrieve Video Options
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
        print("\(self.debugFormatter.string(from: Date())) > enters retrieveVideoAssetFrom in", queueName())

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
                                                resultHandler: { avasset, audioMix, info in
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
                DispatchQueue(label: "prepareVideo").async {
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
                             
    
    // MARK: - Export Video Utilities
    
    private func getExportPreset(for videoAsset: AVAsset) -> String {
        // Determine available export options (highest quality for device by default)
        let presets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)

        // Adopt highest quality by default
        var exportPreset = AVAssetExportPresetHighestQuality
        
        // Determine video size
        let videoSize = videoAsset.tracks(withMediaType: .video).first?.naturalSize ?? CGSize.init(width: 640, height: 480)
        let maxPixels = max(videoSize.width, videoSize.height)
                                                
        // The 'presets' array never contains AVAssetExportPresetPassthrough,
        // so we use determineCompatibilityOfExportPreset.
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
    
    private func getExportSession(for imageAsset: PHAsset,
                                  with options: PHVideoRequestOptions, exportPreset: String,
                                  completionHandler: @escaping (AVAssetExportSession?, Error?) -> Void) {
        print("\(self.debugFormatter.string(from: Date())) > enters getExportSession in", queueName())
        
        // Requests video with selected export preset…
        PHImageManager.default().requestExportSession(forVideo: imageAsset,
                                                      options: options,
                                                      exportPreset: exportPreset,
                                                      resultHandler: { exportSession, info in

            // resultHandler performed on main thread!
            if self.isExecutingBackgroundUploadTask {
//                print("\(self.debugFormatter.string(from: Date())) > exits getExportSession in", queueName())
                // The handler needs to update the user interface => Dispatch to main thread
                if info?[PHImageErrorKey] != nil {
                    // Inform user and propose to cancel or continue
                    let error = info?[PHImageErrorKey] as? Error
                    completionHandler(nil, error)
                    return
                }
                completionHandler(exportSession, nil)
            } else {
                DispatchQueue(label: "prepareVideo").async {
//                    print("\(self.debugFormatter.string(from: Date())) > exits getExportSession in", queueName())
                    // The handler needs to update the user interface => Dispatch to main thread
                    if info?[PHImageErrorKey] != nil {
                        // Inform user and propose to cancel or continue
                        let error = info?[PHImageErrorKey] as? Error
                        completionHandler(nil, error)
                        return
                    }
                    completionHandler(exportSession, nil)
                }
            }
        })
    }

    private func export(imageAsset: PHAsset, with options: PHVideoRequestOptions, exportPreset:String,
                        for uploadID: NSManagedObjectID, with properties: UploadProperties) {
        // Get export session
        self.getExportSession(for: imageAsset,
                              with: options, exportPreset: exportPreset) { (exportSession, error) in
            // Error?
            if let error = error {
                self.didPrepareVideo(for: uploadID, with: properties, error)
                return
            }

            // Valid export session?
            guard let exportSession = exportSession else {
                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                self.didPrepareVideo(for: uploadID, with: properties, error)
                return
            }
            
            // Export video in MP4 format
            self.exportVideo(for: properties, with: exportSession) { (newUploadProperties, error) in
                self.didPrepareVideo(for: uploadID, with: newUploadProperties, error)
            }
        }
    }

    private func export(videoAsset: AVAsset, with exportPreset:String,
                        for uploadID: NSManagedObjectID, with properties: UploadProperties) {
        // Get export session
        guard let exportSession = AVAssetExportSession(asset: videoAsset,
                                                       presetName: exportPreset) else {
            let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            self.didPrepareVideo(for: uploadID, with: properties, error)
            return
        }
        
        // Export video in MP4 format
        self.exportVideo(for: properties, with: exportSession) { (newUploadProperties, error) in
            self.didPrepareVideo(for: uploadID, with: newUploadProperties, error)
        }
    }


    // MARK: - Modify Metadata

    private func exportVideo(for upload: UploadProperties, with exportSession: AVAssetExportSession,
                             completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        print("\(self.debugFormatter.string(from: Date())) > enters modifyVideo in", queueName())
    
        // Strips private metadata if user requested it in Settings
        // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
//        exportSession.metadata = nil
        if upload.stripGPSdataOnUpload {
            exportSession.metadataItemFilter = AVMetadataItemFilter.forSharing()
        } else {
            exportSession.metadataItemFilter = nil
        }

        // Select complete video range
        exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)

        // Video formats — Always export video in MP4 format
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        // ====>> For debugging…
//        print("Supported file types: \(exportSession.supportedFileTypes)")
//        print("Description: \(exportSession.description)")
        // <<==== End of code for debugging

        // Prepare MIME type
        var newUpload = upload
        newUpload.mimeType = "video/mp4"
        newUpload.fileName = URL(fileURLWithPath: upload.fileName ?? "file").deletingPathExtension().appendingPathExtension("MP4").lastPathComponent

        // File name of final video data to be stored into Piwigo/Uploads directory
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-")
        exportSession.outputURL = self.applicationUploadsDirectory.appendingPathComponent(fileName)

        // Deletes temporary video file if exists (incomplete previous attempt?)
        do {
            if let outputURL = exportSession.outputURL {
                try FileManager.default.removeItem(at: outputURL)
            }
        } catch {
        }

        // Export temporary video for upload
        exportSession.exportAsynchronously(completionHandler: {
            switch exportSession.status {
            case .completed:
                // ====>> For debugging…
//                var videoAsset: AVAsset? = nil
//                if let outputURL = exportSession.outputURL {
//                    videoAsset = AVAsset(url: outputURL)
//                }
//                let assetMetadata = videoAsset?.commonMetadata
//                print("Export sucess :-)")
//                if let assetMetadata = assetMetadata {
//                    print("Video metadata: \(assetMetadata)")
//                }
                // <<==== End of code for debugging

                // MD5 checksum of exported video
                if let outputURL = exportSession.outputURL {
                    var videoData: Data = Data()
                    do {
                        try videoData = NSData (contentsOf: outputURL) as Data
                        
                        // Determine MD5 checksum of video file to upload
                        var md5Checksum: String? = ""
                        if #available(iOS 13.0, *) {
                            #if canImport(CryptoKit)        // Requires iOS 13
                            md5Checksum = self.MD5(data: videoData)
                            #endif
                        } else {
                            // Fallback on earlier versions
                            md5Checksum = self.oldMD5(data: videoData)
                        }
                        newUpload.md5Sum = md5Checksum
                        print("\(self.debugFormatter.string(from: Date())) > MD5: \(String(describing: md5Checksum))")

//                        print("\(self.debugFormatter.string(from: Date())) > exits modifyVideo in", queueName())
                        // Upload video with tags and properties
                        completionHandler(newUpload, nil)
                    }
                    catch let error as NSError {
                        // Upload video with tags and properties
                        completionHandler(newUpload, error)
                    }
                }
                return
            
            case .failed:
                // Deletes temporary video file if any
                do {
                    try FileManager.default.removeItem(at: exportSession.outputURL!)
                } catch {
                }

                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(newUpload, error)
                return
                
            case .cancelled:
                // Deletes temporary video file
                do {
                    try FileManager.default.removeItem(at: exportSession.outputURL!)
                } catch {
                }

                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(newUpload, error)
                return
            
            default:
                // Deletes temporary video files
                do {
                    try FileManager.default.removeItem(at: exportSession.outputURL!)
                } catch {
                }

                let error = NSError.init(domain: "Piwigo", code: UploadError.missingAsset.hashValue, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
                completionHandler(newUpload, error)
                return
            }
        })
    }

    private func FourCCString(_ code: FourCharCode) -> String? {
        let result = "\(Int((code >> 24)) & 0xff)\(Int((code >> 16)) & 0xff)\(Int((code >> 8)) & 0xff)\(code & 0xff)"
        let characterSet = CharacterSet.whitespaces
        return result.trimmingCharacters(in: characterSet)
    }
}
