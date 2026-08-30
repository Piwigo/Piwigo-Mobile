//
//  UploadManager+PrepareVideo.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 13/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import AVFoundation
import BackgroundTasks
import MobileCoreServices
import Photos
import CoreData
import PwgKit
import PwgCacheKit
import UniformTypeIdentifiers

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Video of a Live Photo in the Photo Library
    /// Writes the video half of a Live Photo to a file, i.e. the half which the still does not
    /// contain. Its resources are those of an image asset, so the photo half is left untouched.
    func writePairedVideoFromAsset(_ originalAsset: PHAsset, toFile fileURL: URL) async throws(PwgKitError) -> String {
        // Retrieve asset resources
        var resources = PHAssetResource.assetResources(for: originalAsset)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let edited = resources.first(where: { $0.type == .fullSizePairedVideo })
        let original = resources.first(where: { $0.type == .pairedVideo })

        // Priority to the edited video, then to the original version
        /// Both are missing when the Live Photo was converted to a still after this request was created
        guard let resource = edited ?? original
        else {
            // Release memory
            resources.removeAll(keepingCapacity: false)
            throw .missingAsset
        }

        // Name the video after the photo it is paired with, so that both halves are
        // recognisable and named alike on the Piwigo server.
        /// The paired video resource of an edited Live Photo is always named "FullSizeRender.mov",
        /// which would give the same name to every uploaded video.
        let photoName = resources.first(where: { $0.type == .photo })?.originalFilename ?? ""
        let videoExt = URL(fileURLWithPath: resource.originalFilename).pathExtension

        do {
            // Store original data in file
            try await PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: options)

            // Release memory
            resources.removeAll(keepingCapacity: false)

            let bytes = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            UploadManager.logger.notice("Live Photos • Wrote the paired video '\(resource.originalFilename)' (\(bytes) bytes)")

            /// A Live Photo is an image asset, so getFilename() adopted the extension of a photo,
            /// whether it kept the name of the resource or built one from the creation date.
            var fileName = getFilename(fromName: photoName, ofAsset: originalAsset)
            fileName = URL(fileURLWithPath: fileName).deletingPathExtension()
                .appendingPathExtension(videoExt.isEmpty ? "mov" : videoExt).lastPathComponent
            return fileName
        }
        catch let error as NSError where error.domain == PHPhotosErrorDomain {
            // Release memory
            resources.removeAll(keepingCapacity: false)
            throw .photoResourceError(innerError: error)
        }
        catch let error as PwgKitError {
            // Release memory
            resources.removeAll(keepingCapacity: false)
            throw error
        }
        catch {
            // Release memory
            resources.removeAll(keepingCapacity: false)
            throw .otherError(innerError: error)
        }
    }


    // MARK: - Prepare Video from File
    // Case of a video which is in a format accepted by the Piwigo server
    func prepareVideo(atURL originalFileURL: URL, for uploadData: inout UploadProperties) async throws(PwgKitError)
    {
        // Retrieve video data (via a typed URL so AVFoundation can parse the extensionless shared file)
        let (originalVideo, tempVideoURL) = self.readableVideoAsset(at: originalFileURL, fileName: uploadData.fileName)
        defer { if let tempVideoURL { try? FileManager.default.removeItem(at: tempVideoURL) } }
        let trackInfo = await videoTrackInfo(of: UncheckedSendable(originalVideo))
        
        // Get creation date from metadata if possible
        let metadata = originalVideo.metadata
        if let dateFromMetadata = metadata.creationDate() {
            uploadData.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
        } else {
            uploadData.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }
        
        // Rename file according to user's demand from date/time/counter/etc.
        renamedFile(for: &uploadData)

        // Check if the user wants to:
        /// - reduce the frame size
        /// - remove the private metadata
        let hasPrivateMetadata = metadata.containsPrivateMetadata()
        /// An HDR video is tone-mapped to SDR, which requires the server to accept MP4 files.
        let shouldToneMapHDR = uploadData.serverFileTypes.contains("mp4") && (trackInfo?.isHDR ?? false)
        UploadManager.logger.notice("Prepare video \(uploadData.fileName) from file — \(originalFileURL.fileSize) bytes, \(trackInfo?.description ?? "no video track"), private metadata: \(hasPrivateMetadata ? "yes" : "no"), tone-map: \(shouldToneMapHDR ? "yes" : "no")")
        if (uploadData.resizeImageOnUpload && uploadData.videoMaxSize != 0) ||
            (uploadData.stripGPSdataOnUpload && hasPrivateMetadata) || shouldToneMapHDR {
            // Check that the video can be exported
            try await checkVideoExportability(of: originalVideo)
            
            // File name of final video data to be stored into Piwigo/Uploads directory
            let outputURL = getUploadFileURL(for: uploadData)

            // Export new video in MP4 format w/ or w/o private metadata
            try await export(videoAsset: originalVideo, to: outputURL, with: &uploadData)
            
            // Get MD5 checksum and MIME type
            try setMD5sumAndMIMEtype(using: &uploadData, forFileAtURL: outputURL)
        }
        else {
            // Get MD5 checksum and MIME type, change URL
            try setMD5sumAndMIMEtype(using: &uploadData, forFileAtURL: originalFileURL)
        }
    }
    
    // Case of a video which is in a format not accepted by the Piwigo server
    func convertVideo(atURL originalFileURL: URL, for uploadData: inout UploadProperties) async throws(PwgKitError)
    {
        // Retrieve video data (via a typed URL so AVFoundation can parse the extensionless shared file)
        let (originalVideo, tempVideoURL) = self.readableVideoAsset(at: originalFileURL, fileName: uploadData.fileName)
        defer { if let tempVideoURL { try? FileManager.default.removeItem(at: tempVideoURL) } }
        
        // Get creation date from metadata if possible
        let metadata = originalVideo.metadata
        if let dateFromMetadata = metadata.creationDate() {
            uploadData.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
        } else {
            uploadData.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }
        
        // Rename file according to user's demand from date/time/counter/etc.
        renamedFile(for: &uploadData)

        // Check that the video can be exported
        try await checkVideoExportability(of: originalVideo)
        
        // File name of final video data to be stored into Piwigo/Uploads directory
        let outputURL = getUploadFileURL(for: uploadData)

        // Export new video in MP4 format w/ or w/o private metadata
        try await export(videoAsset: originalVideo, to: outputURL, with: &uploadData)
        
        // Get MD5 checksum and MIME type, update counter
        try setMD5sumAndMIMEtype(using: &uploadData, forFileAtURL: outputURL)
    }
    
    // Check the exportability of a video (modern version)
    fileprivate func checkVideoExportability(of originalVideo: AVAsset) async throws(PwgKitError) {
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

    // Returns an AVAsset the system can parse for a shared file stored WITHOUT an extension (the
    // share/intent/clipboard media files are named by their identifier only). AVFoundation needs the
    // container type: on iOS 17+ override the MIME type; on older systems hard-link a typed alias in
    // the same directory (same filesystem, no data copy). Also returns the temporary link to remove.
    private func readableVideoAsset(at fileURL: URL, fileName: String) -> (asset: AVAsset, tempURL: URL?) {
        let ext = URL(fileURLWithPath: fileName).pathExtension
        if #available(iOS 17, *) {
            var options: [String: Any] = [:]
            if let utType = UTType(filenameExtension: ext), let mimeType = utType.preferredMIMEType {
                options[AVURLAssetOverrideMIMETypeKey] = mimeType
            }
            return (AVURLAsset(url: fileURL, options: options), nil)
        } else if ext.isEmpty == false {
            let linkURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent("pwgVid-" + UUID().uuidString).appendingPathExtension(ext)
            if (try? FileManager.default.linkItem(at: fileURL, to: linkURL)) != nil {
                return (AVURLAsset(url: linkURL), linkURL)
            }
        }
        return (AVURLAsset(url: fileURL), nil)
    }

    
    // MARK: - Prepare Video from Photo Library Asset
    // Case of a video from the Photo Library which is in a format accepted by the Piwigo server
    func prepareVideo(ofAsset imageAsset: PHAsset, atURL outputURL: URL,
                      for uploadData: inout UploadProperties, withID uploadID: NSManagedObjectID,
                      inTaskType taskType: UploadTaskType) async throws(PwgKitError)
    {
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Prepare video \(uploadData.fileName) from Asset")

        // Retrieve video data
        /// The date is captured here because a composition carries no metadata to derive it from.
        let assetCreationDate = imageAsset.creationDate
        let options = getVideoRequestOptions()
        let boxedVideo = try await retrieveVideo(from: imageAsset, with: options)
        let originalVideo = boxedVideo.value
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Returned AVAsset")

        // Stop preparing the video if called by a background task now expired
        /// Reported as a cancellation so that the request remains retryable.
        if taskType.isBackgroundAndInactive {
            throw PwgKitError.otherError(innerError: CancellationError())
        }

        /// The asset properties must be loaded before the synchronous accessors below are read,
        /// and loading is asynchronous.
        let trackInfo = await videoTrackInfo(of: boxedVideo)

        // Get original fileURL if any
        let originalFileURL = (originalVideo as? AVURLAsset)?.url

        // Check if the user wants to:
        /// - reduce the frame size
        /// - remove the private metadata
        let hasPrivateMetadata = originalVideo.metadata.containsPrivateMetadata()
        /// An HDR video is tone-mapped to SDR, which requires the server to accept MP4 files.
        let shouldToneMapHDR = uploadData.serverFileTypes.contains("mp4")
                            && (trackInfo?.isHDR ?? false)
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • AVAsset file: \(originalFileURL?.lastPathComponent ?? "none (composition)"), \(originalFileURL?.fileSize ?? 0) bytes, \(trackInfo?.description ?? "no video track"), private metadata: \(hasPrivateMetadata ? "yes" : "no"), tone-map: \(shouldToneMapHDR ? "yes" : "no")")

        // Get creation date from metadata if possible
        let metadata = originalVideo.metadata
        if let dateFromMetadata = metadata.creationDate() {
            uploadData.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
        }
        else if let originalFileURL {
            uploadData.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }
        else {
            // Case of a composition (slow-motion, edited video): it carries no
            // metadata and has no file, so adopt the Photo Library's own date.
            uploadData.creationDate = (assetCreationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }

        // Rename file according to user's demand from date/time/counter/etc.
        renamedFile(for: &uploadData)

        // Export when a modification is requested, when the asset has no file to copy,
        // or when the capture is HDR; otherwise upload the original file as is.
        if (uploadData.resizeImageOnUpload && uploadData.videoMaxSize != 0) ||
            (uploadData.stripGPSdataOnUpload && hasPrivateMetadata) ||
            (originalFileURL == nil) || shouldToneMapHDR {
            // Check that the video can be exported
            try await checkVideoExportability(of: originalVideo)

            // Export new video in MP4 format w/ or w/o private metadata
            try await export(videoAsset: originalVideo, to: outputURL, with: &uploadData)

            // Get MD5 checksum and MIME type
            try setMD5sumAndMIMEtype(using: &uploadData, forFileAtURL: outputURL)
        }
        else if let originalFileURL {
            // Copy video file into Piwigo/Uploads directory
            // Get MD5 checksum and MIME type, change URL
            try setMD5sumAndMIMEtype(using: &uploadData, forFileAtURL: originalFileURL)
        }
        else {
            throw PwgKitError.missingAsset
        }

        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Did finish preparing video from PHAsset.")
    }
    
    // Case of a video from the Photo Library which is in a format not accepted by the Piwigo server
    func convertVideo(ofAsset imageAsset: PHAsset, atURL outputURL: URL,
                      for uploadData: inout UploadProperties, withID uploadID: NSManagedObjectID,
                      inTaskType taskType: UploadTaskType) async throws(PwgKitError)
    {
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Convert video \(uploadData.fileName) from Asset")

        // Retrieve video data
        /// The date is captured here because a composition carries no metadata to derive it from.
        let assetCreationDate = imageAsset.creationDate
        let options = getVideoRequestOptions()
        let boxedVideo = try await retrieveVideo(from: imageAsset, with: options)
        let originalVideo = boxedVideo.value
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Returned AVAsset")

        // Stop converting the video if called by a background task now expired
        /// Reported as a cancellation so that the request remains retryable.
        if taskType.isBackgroundAndInactive {
            throw PwgKitError.otherError(innerError: CancellationError())
        }

        // Get creation date from metadata if possible
        let metadata = originalVideo.metadata
        if let dateFromMetadata = metadata.creationDate() {
            uploadData.creationDate = dateFromMetadata.timeIntervalSinceReferenceDate
        }
        else if let originalFileURL = (originalVideo as? AVURLAsset)?.url {
            uploadData.creationDate = (originalFileURL.creationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }
        else {
            // Case of a composition (slow-motion, edited video): it carries no
            // metadata and has no file, so adopt the Photo Library's own date.
            uploadData.creationDate = (assetCreationDate ?? DateUtilities.unknownDate).timeIntervalSinceReferenceDate
        }

        // Rename file according to user's demand from date/time/counter/etc.
        renamedFile(for: &uploadData)

        // Check that the video can be exported
        try await checkVideoExportability(of: originalVideo)

        // Export new video in MP4 format w/ or w/o private metadata
        try await export(videoAsset: originalVideo, to: outputURL, with: &uploadData)

        // Get MD5 checksum and MIME type, update counter
        try setMD5sumAndMIMEtype(using: &uploadData, forFileAtURL: outputURL)

        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Did finish converting video from PHAsset.")
    }
    
    // MARK: - Video Track Description
    /// Reads the properties of the video track.
    /// The asynchronous loader does not populate the deprecated synchronous accessors, so every
    /// reader goes through this: reading `tracks(withMediaType:)` on an asset that the legacy path
    /// has not already loaded silently reports no track, which would hide an HDR capture and
    /// collapse the export preset to 640x480.
    nonisolated func videoTrackInfo(of boxedAsset: UncheckedSendable<AVAsset>) async -> VideoTrackInfo? {
        let videoAsset = boxedAsset.value
        let size: CGSize, frameRate: Float, dataRate: Float, formats: [CMFormatDescription]
        if #available(iOS 16.0, *) {
            guard let track = try? await videoAsset.loadTracks(withMediaType: .video).first,
                  let loaded = try? await track.load(.naturalSize, .nominalFrameRate,
                                                     .estimatedDataRate, .formatDescriptions)
            else { return nil }
            (size, frameRate, dataRate, formats) = loaded
        } else {
            // Fallback on earlier versions, where the synchronous accessors block and load
            guard let track = videoAsset.tracks(withMediaType: .video).first
            else { return nil }
            size = track.naturalSize
            frameRate = track.nominalFrameRate
            dataRate = track.estimatedDataRate
            formats = (track.formatDescriptions as? [CMFormatDescription]) ?? []
        }
        return VideoTrackInfo(size: size, frameRate: frameRate, dataRate: dataRate, formats: formats)
    }

    /// Reads the properties of the video track of a file on disk.
    /// The upload files are named after the file key and carry no extension, so the asset is typed
    /// from the upload file name — without it AVFoundation cannot parse the container at all.
    func videoTrackInfo(ofFileAt url: URL, named fileName: String) async -> VideoTrackInfo? {
        let (videoAsset, tempVideoURL) = self.readableVideoAsset(at: url, fileName: fileName)
        defer { if let tempVideoURL { try? FileManager.default.removeItem(at: tempVideoURL) } }
        return await videoTrackInfo(of: UncheckedSendable(videoAsset))
    }


    // MARK: - Retrieve Video Asset
    /// Used to retrieve video data from the PhotoLibrary
    func getVideoFileName(from originalAsset: PHAsset) -> String {
        // Retrieve original filename from asset resources
        let resources = PHAssetResource.assetResources(for: originalAsset)
        let original = resources.first(where: { $0.type == .photo || $0.type == .video || $0.type == .audio })
        let originalFilename = original?.originalFilename ?? ""
        let filename = getFilename(fromName: originalFilename, ofAsset: originalAsset)
        return filename
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
        unsafe options.progressHandler = { progress, error, stop, dict in
            #if DEBUG
            debugPrint("downloading Video — progress \(progress)")
            #endif
//         The handler needs to update the user interface => Dispatch to main thread
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
//            if let metadata = avasset?.metadata {
//                debugPrint("=> Metadata: \(metadata)\r=> Creation date: \(metadata.creationDate() ?? DateUtilities.unknownDate)")
//            }
//            if let creationDate = avasset?.creationDate {
//                debugPrint("=> Creation date: \(creationDate)")
//            }
//            debugPrint("=> Exportable: \(avasset?.isExportable ?? false ? "Yes" : "No")")
//            if let avasset = avasset {
//                debugPrint("=> Compatibility: \(AVAssetExportSession.exportPresets(compatibleWith: avasset))")
//            }
//            if let tracks = avasset?.tracks {
//                debugPrint("=> Tracks: \(tracks)")
//            }
//            for track in avasset?.tracks ?? [] {
//                if track.mediaType == .video {
//                    debugPrint(String(format: "=>       : %.f x %.f", track.naturalSize.width, track.naturalSize.height))
//                }
//                var format = ""
//                for i in 0..<track.formatDescriptions.count {
//                    let desc = (track.formatDescriptions[i]) as! CMFormatDescription
//                    // Get String representation of media type (vide, soun, sbtl, etc.)
//                    var type: String? = nil
//                    type = CMFormatDescriptionGetMediaType(desc).toString()
//                    // Get String representation media subtype (avc1, aac, tx3g, etc.)
//                    var subType: String? = nil
//                    subType = CMFormatDescriptionGetMediaSubType(desc).toString()
//                    // Format string as type/subType
//                    format.append(contentsOf: "\(type ?? "")/\(subType ?? "")")
//                    // Comma separate if more than one format description
//                    if i < track.formatDescriptions.count - 1 {
//                        format.append(contentsOf: ",")
//                    }
//                }
//                debugPrint("=>       : \(format)")
//            }
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
    
    /// Bridges the callback-based retrieval above into structured concurrency, so that the caller
    /// keeps awaiting while Photos loads — and possibly downloads from iCloud — the video.
    /// The continuation is resumed from the Photos result handler, i.e. from another thread, which
    /// is safe: the awaiting actor-isolated caller resumes on its own executor.
    /// The AVAsset is boxed because AVFoundation objects are not Sendable.
    nonisolated func retrieveVideo(from imageAsset: PHAsset,
                                   with options: PHVideoRequestOptions) async throws(PwgKitError) -> UncheckedSendable<AVAsset> {
        let result: (UncheckedSendable<AVAsset>?, PwgKitError?) = await withCheckedContinuation { continuation in
            retrieveVideo(from: imageAsset, with: options) { avasset, error in
                continuation.resume(returning: (avasset.map { UncheckedSendable($0) }, error))
            }
        }
        if let error = result.1 { throw error }
        guard let boxedVideo = result.0 else { throw PwgKitError.missingAsset }
        return boxedVideo
    }
    
    
    // MARK: - Export Video
    // Determine video size and reduce it if requested
    // Export the video in MP4 format w/ or w/o private metadata
    private func export(videoAsset: AVAsset, to outputURL: URL, with uploadData: inout UploadProperties) async throws(PwgKitError)
    {
        // Read the track once: the preset and the HDR test below both depend on it
        let trackInfo = await videoTrackInfo(of: UncheckedSendable(videoAsset))

        // Determine available export options (highest quality for device by default)
        let presets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)
        
        // Produce QuickTime movie file with video size appropriate to the current device by default
        /// - The export will not scale the video up from a smaller size.
        /// - Compression for video uses H.264; compression for audio uses AAC.
        var exportPreset = AVAssetExportPresetHighestQuality
        
        // Determine video size
        /// A missing video track falls back to 640x480, i.e. to the smallest export preset.
        let videoSize = trackInfo?.size ?? CGSize(width: 640, height: 480)
        var maxPixels = Int(max(videoSize.width, videoSize.height))
        
        // Resize frames
        if uploadData.resizeImageOnUpload, uploadData.videoMaxSize != 0 {
            maxPixels = pwgVideoMaxSizes(rawValue: uploadData.videoMaxSize)?.pixels ?? Int.max
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
        } else if (maxPixels <= 3840) && presets.contains(AVAssetExportPreset3840x2160) {
            // Encode in 3840x2160 pixels — metadata will be lost
            exportPreset = AVAssetExportPreset3840x2160
        }

        // Tone-map an HDR capture to SDR
        /// The size-bucketed presets encode H.264, which carries no HDR, but the highest-quality
        /// preset may preserve it — so an HDR source is pinned to the largest bucket it fits in.
        /// NB: an AVMutableVideoComposition stating the output colour explicitly was tried here.
        /// It tone-mapped correctly, but it also rebuilt the frame: the composition that the Photo
        /// Library returns for a slow-motion clip lost its rotation and was exported landscape,
        /// with the portrait picture pillarboxed. The preset alone is relied upon instead.
        let isHDR = trackInfo?.isHDR ?? false
        if isHDR, exportPreset == AVAssetExportPresetHighestQuality {
            if presets.contains(AVAssetExportPreset3840x2160) {
                exportPreset = AVAssetExportPreset3840x2160
            } else if presets.contains(AVAssetExportPreset1920x1080) {
                exportPreset = AVAssetExportPreset1920x1080
            }
        }

        UploadManager.logger.notice("Exporting \(uploadData.fileName) — track: \(trackInfo?.description ?? "none!"), preset: \(exportPreset), HDR: \(isHDR ? "yes" : "no")")

        // Get export session
        guard let exportSession = AVAssetExportSession(asset: videoAsset,
                                                       presetName: exportPreset)
        else { throw .missingAsset }
        
        // Set parameters
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)
        exportSession.outputURL = outputURL

        // Strips private metadata if user requested it in Settings
        // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
        if uploadData.stripGPSdataOnUpload {
            exportSession.metadataItemFilter = AVMetadataItemFilter.forSharing()
        } else {
            exportSession.metadata = videoAsset.metadata
        }
        
        // ====>> For debugging…
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
        // <<==== End of code for debugging

        // Prepare MIME type, file
        uploadData.mimeType = "video/mp4"
        uploadData.fileName = URL(fileURLWithPath: uploadData.fileName)
            .deletingPathExtension().appendingPathExtension("MP4").lastPathComponent
        do {
            // Export temporary video for upload
            try await exportSession.export(to: outputURL, as: .mp4)
            let exported = await videoTrackInfo(ofFileAt: outputURL, named: uploadData.fileName)
            UploadManager.logger.notice("Exported \(uploadData.fileName) — \(outputURL.fileSize) bytes, \(exported?.description ?? "no video track")")
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
}


// MARK: - Video Track Properties
/// The properties of a video track, read once and carried as values so that they can cross
/// isolation boundaries — AVAssetTrack cannot.
struct VideoTrackInfo: Sendable {
    let size: CGSize
    let frameRate: Float
    let dataRate: Float
    let formats: [String]
    let primaries: String
    let transfer: String
    let matrix: String

    init(size: CGSize, frameRate: Float, dataRate: Float, formats: [CMFormatDescription]) {
        self.size = size
        self.frameRate = frameRate
        self.dataRate = dataRate
        /// A composition reports one format description per segment, so the repeats are dropped.
        var uniqueFormats = [String]()
        for desc in formats {
            // Media type and subtype as strings, e.g. "vide/hvc1"
            let type = CMFormatDescriptionGetMediaType(desc).toString()
            let subType = CMFormatDescriptionGetMediaSubType(desc).toString()
            let format = "\(type)/\(subType)"
            if uniqueFormats.contains(format) == false {
                uniqueFormats.append(format)
            }
        }
        self.formats = uniqueFormats
        func extensionValue(_ key: CFString) -> String {
            guard let desc = formats.first,
                  let value = CMFormatDescriptionGetExtension(desc, extensionKey: key) as? String
            else { return "—" }
            return value
        }
        self.primaries = extensionValue(kCMFormatDescriptionExtension_ColorPrimaries)
        self.transfer = extensionValue(kCMFormatDescriptionExtension_TransferFunction)
        self.matrix = extensionValue(kCMFormatDescriptionExtension_YCbCrMatrix)
    }

    /// Whether the track carries an HDR transfer function. Such a video looks washed out wherever
    /// the HLG/PQ curve is ignored, which is what the Piwigo server and most web players do, so it
    /// is tone-mapped to SDR before being uploaded — exactly what Photos does for the shared file.
    var isHDR: Bool {
        return [kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String,
                kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String].contains(transfer)
    }

    /// An HDR capture reports Rec.2020 primaries with an HLG or PQ transfer function,
    /// an SDR one reports Rec.709 throughout.
    var description: String {
        return "\(Int(size.width))x\(Int(size.height)) \(formats.joined(separator: ",")) @ "
            + "\(String(format: "%.0f", frameRate)) fps, \(Int(dataRate / 1000)) kbps, "
            + "colour \(primaries)/\(transfer)/\(matrix)"
    }
}


// MARK: - Sendable Box
/// AVFoundation objects are safe to load properties on from any thread but are not marked
/// Sendable, so they are boxed to be handed to an asynchronous loader.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
