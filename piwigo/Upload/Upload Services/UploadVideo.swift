//
//  UploadVideo.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import AVFoundation
import Photos

class UploadVideo {
    
    func prepare(_ upload: UploadProperties, from imageAsset: PHAsset,
                 completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { (avasset, options, error) in
            // Error?
            if let error = error {
                completionHandler(upload, error)
                return
            }

            // Valid AVAsset?
            guard let originalVideo = avasset else {
                // define error !!!!
                completionHandler(upload, error)
                return
            }
            
            // Get MIME type
            guard let originalFileURL = (originalVideo as? AVURLAsset)?.url else {
                // define error !!!!
                completionHandler(upload, error)
                return
            }
            guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, originalFileURL.pathExtension as NSString, nil)?.takeRetainedValue() else {
                // define error !!!!
                completionHandler(upload, error)
                return
            }
            guard let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() else  {
                // define error !!!!
                completionHandler(upload, error)
                return
            }
            var newUpload = upload
            newUpload.mimeType = mimeType as String

            // Determine if metadata contains private data
            let assetMetadata = originalVideo.commonMetadata
            let locationMetadata = AVMetadataItem.metadataItems(from: assetMetadata, filteredByIdentifier: .commonIdentifierLocation)

            // Upload original video if metedata matches user's choice
            if !Model.sharedInstance().stripGPSdataOnUpload ||
                (Model.sharedInstance().stripGPSdataOnUpload && (locationMetadata.count == 0)) {

                // Copy video into Piwigo/Upload directory
                let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-") + "-" + upload.fileName!
                let fileURL = UploadManager.applicationUploadsDirectory.appendingPathComponent(fileName)
                do {
                    try FileManager.default.copyItem(at: originalFileURL, to: fileURL)
                    // Upload video with tags and properties
                    completionHandler(newUpload, nil)
                    return
                }
                catch let error as NSError {
                    print("Ooops! Something went wrong: \(error)")
                    completionHandler(upload, nil)
                    return
                }
            }
            
            // Remove metadata by exporting a new video in MP4 format
            // Determine optimal export options (highest quality for device by default)
            let exportPreset = self.getExportPreset(for: imageAsset, and: originalVideo)
            
            // Get export session
            self.getExportSession(imageAsset: imageAsset, options: options, exportPreset: exportPreset) { (exportSession, error) in
                // Error?
                if let error = error {
                    completionHandler(upload, error)
                    return
                }

                // Valid export session?
                guard let exportSession = exportSession else {
                    // define error !!!!
                    completionHandler(upload, error)
                    return
                }
                
                // Export video in MP4 format
                self.modifyVideo(for: upload, with: exportSession) { (newUpload, error) in
                    // Error?
                    if let error = error {
                        completionHandler(newUpload, error)
                        return
                    }
                    completionHandler(newUpload, nil)
                    return
                }
            }

            // Could not prepare the video file
            completionHandler(upload, nil)
//                    self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_export", comment: "Sorry, the video could not be retrieved for the upload. Error: \(exportSession?.error?.localizedDescription ?? "")"), forRetrying: false, withImage: image)
            return
        }

        // Could not retrieve the video
        // define error !!!!
        completionHandler(upload, nil)
//        self.showError(withTitle: NSLocalizedString("uploadCancelled_title", comment: "Upload Cancelled"), andMessage: NSLocalizedString("videoUploadCancelled_message", comment: "The upload of the video has been cancelled."), forRetrying: true, withImage: image)
    }
    
    func convert(_ imageAsset: PHAsset, for upload: UploadProperties,
                 completionHandler: @escaping (UploadProperties, Error?) -> Void) {
        // Retrieve video data
        let options = getVideoRequestOptions()
        retrieveVideo(from: imageAsset, with: options) { (avasset, options, error) in
            // Error?
            if let error = error {
                completionHandler(upload, error)
                return
            }

            // Valid AVAsset?
            guard let avasset = avasset else {
                // define error !!!!
                completionHandler(upload, error)
                return
            }
            
            // Determine optimal export options (highest quality for device by default)
            let exportPreset = self.getExportPreset(for: imageAsset, and: avasset)

            // Get export session
            self.getExportSession(imageAsset: imageAsset, options: options, exportPreset: exportPreset) { (exportSession, error) in
                // Error?
                if let error = error {
                    completionHandler(upload, error)
                    return
                }

                // Valid export session?
                guard let exportSession = exportSession else {
                    // define error !!!!
                    completionHandler(upload, error)
                    return
                }
                
                // Export video in MP4 format
                self.modifyVideo(for: upload, with: exportSession) { (newUpload, error) in
                    // Error?
                    if let error = error {
                        completionHandler(newUpload, error)
                        return
                    }
                    completionHandler(newUpload, nil)
                }
            }
        }
    }

    
    // MARK: - Retrieve Video
    
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
    
    private func getExportPreset(for imageAsset: PHAsset, and avasset: AVAsset) -> String {
        // Determine available export options (highest quality for device by default)
        var exportPreset = AVAssetExportPresetHighestQuality
        let maxPixels = max(imageAsset.pixelWidth ,imageAsset.pixelHeight)
        var presets: [String]? = nil
        presets = AVAssetExportSession.exportPresets(compatibleWith: avasset)
                                                
        // The 'presets' array never contains AVAssetExportPresetPassthrough,
        // so we use determineCompatibilityOfExportPreset.
        if (maxPixels <= 640) && (presets?.contains(AVAssetExportPreset640x480)) ?? false {
            // Encode in 640x480 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset640x480
        } else if (maxPixels <= 960) && (presets?.contains(AVAssetExportPreset960x540)) ?? false {
            // Encode in 960x540 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset960x540
        } else if (maxPixels <= 1280) && (presets?.contains(AVAssetExportPreset1280x720)) ?? false {
            // Encode in 1280x720 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset1280x720
        } else if (maxPixels <= 1920) && (presets?.contains(AVAssetExportPreset1920x1080)) ?? false {
            // Encode in 1920x1080 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset1920x1080
        } else if (maxPixels <= 3840) && (presets?.contains(AVAssetExportPreset1920x1080)) ?? false {
            // Encode in 1920x1080 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset3840x2160
        }
        return exportPreset
    }
    
    private func retrieveVideo(from imageAsset: PHAsset, with options: PHVideoRequestOptions,
                               completionHandler: @escaping (AVAsset?, PHVideoRequestOptions, Error?) -> Void) {
        print("•••> retrieveVideoAssetFrom...")

        // The block Photos calls periodically while downloading the video.
        options.progressHandler = { progress, error, stop, dict in
        #if DEBUG_UPLOAD
            print(String(format: "downloading Video from iCloud — progress %lf", progress))
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
            
            // Any error?
            if info?[PHImageErrorKey] != nil {
                print("     returned info(\(String(describing: info)))")
                let error = info?[PHImageErrorKey] as? Error
                completionHandler(nil, options, error)
                return
            }
            completionHandler(avasset, options, nil)
        })
    }
                             
    private func getExportSession(imageAsset: PHAsset, options: PHVideoRequestOptions, exportPreset: String,                                           completionHandler: @escaping (AVAssetExportSession?, Error?) -> Void) {
        print("•••> getExportSession...")
        
        // Requests video with selected export preset…
        PHImageManager.default().requestExportSession(forVideo: imageAsset,
                                                      options: options,
                                                      exportPreset: exportPreset,
                                                      resultHandler: { exportSession, info in
            // The handler needs to update the user interface => Dispatch to main thread
            if info?[PHImageErrorKey] != nil {
                // Inform user and propose to cancel or continue
                let error = info?[PHImageErrorKey] as? Error
                completionHandler(nil, error)
//                                    self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_iCloud", comment: "Could not retrieve video. Error: \(error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
                return
            }
            completionHandler(exportSession, nil)
        })
    }


    // MARK: - Modify Metadata

    private func modifyVideo(for upload: UploadProperties, with exportSession: AVAssetExportSession,
                             completionHandler: @escaping (UploadProperties, Error?) -> Void) {
    print("•••> modifyVideo...")
    
        // Strips private metadata if user requested it in Settings
        // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
//        exportSession.metadata = nil
        if Model.sharedInstance().stripGPSdataOnUpload {
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
        newUpload.fileName = URL(fileURLWithPath: upload.fileName ?? "file").deletingPathExtension().appendingPathExtension("mp4").lastPathComponent

        // File name of final video data to be stored into Piwigo/Uploads directory
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-") + "-" + upload.fileName!
        exportSession.outputURL = UploadManager.applicationUploadsDirectory.appendingPathComponent(fileName)

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

                // Upload video with tags and properties
                completionHandler(newUpload, nil)
                return
            
            case .failed:
                // Deletes temporary video file if any
                do {
                    try FileManager.default.removeItem(at: exportSession.outputURL!)
                } catch {
                }

                // define error !!!!
                completionHandler(newUpload, nil)
//                self.showError(withTitle: NSLocalizedString("uploadCancelled_title", comment: "Upload Cancelled"), andMessage: NSLocalizedString("videoUploadCancelled_message", comment: "The upload of the video has been cancelled."), forRetrying: true, withImage: image)
                return
                
            case .cancelled:
                // Deletes temporary video file
                do {
                    try FileManager.default.removeItem(at: exportSession.outputURL!)
                } catch {
                }

                // Inform user
                // define error !!!!
                completionHandler(newUpload, nil)
//                self.showError(withTitle: NSLocalizedString("uploadCancelled_title", comment: "Upload Cancelled"), andMessage: NSLocalizedString("videoUploadCancelled_message", comment: "The upload of the video has been cancelled."), forRetrying: true, withImage: image)
                return
            
            default:
                // Deletes temporary video files
                do {
                    try FileManager.default.removeItem(at: exportSession.outputURL!)
                } catch {
                }

                // Inform user
                // define error !!!!
                completionHandler(newUpload, nil)
//                self.showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_unknown", comment: "Sorry, the upload of the video has failed for an unknown error during the MP4 conversion. Error: \(exportSession?.error?.localizedDescription ?? "")"), forRetrying: true, withImage: image)
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
