//
//  ImageUploadDispatcher.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos

@objc
class ImageUploadDispatcher: NSObject, NSFetchedResultsControllerDelegate {

    // Singleton
    static var instance: ImageUploadDispatcher = ImageUploadDispatcher()
    class func sharedInstance() -> ImageUploadDispatcher {
        return instance
    }
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()



    // MARK: - Background Tasks Instances
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var imagePreparation: ImageUploadPreparation = {
        let instance : ImageUploadPreparation = ImageUploadPreparation()
        return instance
    }()

    
    // MARK: - Background Tasks Dispatcher
    /**
     The dispatcher first launches an upload if there is one already prepared.
     It then prepares another upload.
     */
    func findNextImageToUpload() {
        print("•••>> findNextImageToUpload…")

        // Quit if no upload in store
        guard let allUploads = uploadsProvider.fetchedResultsController.fetchedObjects else {
            return
        }
        
        // Prepare the next upload if no preparation already in progress
        if allUploads.first(where: { $0.state == .preparing }) == nil {
            findNextImageToPrepare(in: allUploads)
        }

        // Quit if is already uploading
        if allUploads.first(where: { $0.state == .uploading }) != nil {
            return
        }

        
        
    }

    func findNextImageToPrepare(in allUploads:[Upload]) {
        print("•••>> findNextImageToPrepare…")

        // Quit if already preparing an upload
        if allUploads.first(where: { $0.state == .preparing }) != nil {
            print("•••>> already preparing an upload…")
            return
        }
        
        // Quit if no upload to prepare
        guard let uploadToPrepare = allUploads.first(where: { $0.state == .waiting }) else {
            print("•••>> no upload to prepare")
            return
        }
        
        // Retrieve image asset
        guard let originalAsset = PHAsset.fetchAssets(withLocalIdentifiers: [uploadToPrepare.localIdentifier], options: nil).firstObject else {
            return
        }

        // Determine non-empty unique file name and extension from asset
        uploadToPrepare.fileName = PhotosFetch.sharedInstance().getFileNameFomImageAsset(originalAsset)
        let fileExt = (URL(fileURLWithPath: uploadToPrepare.fileName!).pathExtension).lowercased()
        
        // Set upload properties
        var uploadProperties = UploadProperties.init(localIdentifier: uploadToPrepare.localIdentifier, category: Int(uploadToPrepare.category),
                                                     requestDate: uploadToPrepare.requestDate, requestState: uploadToPrepare.state,
                                                     creationDate: originalAsset.creationDate, fileName: uploadToPrepare.fileName,
                                                     author: uploadToPrepare.author, privacyLevel: uploadToPrepare.privacy,
                                                     title: uploadToPrepare.title,
                                                     comment: uploadToPrepare.comment,
                                                     tags: uploadToPrepare.tags)

        // Launch preparation job if file format accepted by Piwigo server
        switch originalAsset.mediaType {
        case .image:
            // Chek that the image format is accepted by the Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                print("•••>> preparing photo \(uploadToPrepare.fileName!)…")
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                    // Launch preparation job
                    DispatchQueue.global(qos: .background).async {
                        self.imagePreparation.retrieveUIImageFrom(imageAsset: originalAsset, for: uploadProperties)
                    }
                })
                return
            }
            if Model.sharedInstance().uploadFileTypes.contains("jpg") {
                // Conversion to JPEG is possible for some file formats
                if fileExt == "heic" || fileExt == "heif" || fileExt == "avci" {
                    // Will convert HEIC encoded image to JPEG
                    print("•••>> preparing photo \(uploadToPrepare.fileName!)…")
                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                        // Launch preparation job
                        DispatchQueue.global(qos: .background).async {
                            self.imagePreparation.retrieveUIImageFrom(imageAsset: originalAsset, for: uploadProperties)
                        }
                    })
                    return
                }
            }
            // Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToPrepare(in: allUploads)
            })
//            showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_format", comment: "Sorry, image files with extensions .\(fileExt.uppercased()) and .jpg are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)

        case .video:
            // Chek that the video format is accepted by the Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains(fileExt) {
                // Video file format accepted by the Piwigo server
                print("•••>> preparing video \(uploadToPrepare.fileName!)…")

                return
            }
            if Model.sharedInstance().uploadFileTypes.contains("mp4") {
                // Conversion to MP4 is possible
                if fileExt == "mov" {
                    // Will convert MOV encoded video to MP4
                    uploadToPrepare.fileName = URL(fileURLWithPath: URL(fileURLWithPath: uploadToPrepare.fileName!).deletingPathExtension().absoluteString).appendingPathExtension("mp4").absoluteString
                    print("•••>> preparing video \(uploadToPrepare.fileName!)…")
                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                        // Launch preparation job
                        DispatchQueue.global(qos: .background).async {

                        }
                    })
                    return
                }
            }
            // Video file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToPrepare(in: allUploads)
            })
//                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt.uppercased()) are not accepted by the Piwigo server."), forRetrying: false, withImage: uploadToPrepare)

        case .audio:
            // Not managed by Piwigo iOS yet…
            uploadProperties.requestState = .formatError
            uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToPrepare(in: allUploads)
            })
//            showError(withTitle: NSLocalizedString("audioUploadError_title", comment: "Audio Upload Error"), andMessage: NSLocalizedString("audioUploadError_format", comment: "Sorry, audio files are not supported by Piwigo Mobile yet."), forRetrying: false, withImage: uploadToPrepare)

        case .unknown:
            fallthrough
        default:
            // Unknown format
            uploadProperties.requestState = .formatError
            uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToPrepare(in: allUploads)
            })
        }
    }
    
    func didFinishPreparing(upload: UploadProperties, with mimeType: String, imageData: Data?) {
        
        // Update state of upload
        var uploadProperties = upload
        uploadProperties.requestState = .uploading
        uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
            // Launch transfer if possible
            print("•••>> preparing transfer of \(upload.fileName!)…")
            DispatchQueue.global(qos: .background).async {
                ImageUploadTransfer.uploadImage(imageData, with: uploadProperties, mimeType: mimeType,
                                                onProgress: { (progress, currentChunk, totalChunks) in
                                                    print("……… progress: \(progress?.completedUnitCount ?? 0), \(progress?.totalUnitCount ?? 0), \(currentChunk), \(totalChunks)")
                },
                                                onCompletion: { (task, response) in
                                                    print("……… completion: \(String(describing: response))")
                                                    uploadProperties.requestState = .uploaded
                                                    self.uploadsProvider.importUploads(from: [uploadProperties], completionHandler: { _ in
                                                        print("……… upload complete ;-)")
                                                    })
                },
                                                onFailure: { (task, error) in
                                                    if let error = error {
                                                        print("ERROR IMAGE UPLOAD: \(error)")
                                                    }
                })
            }
        })
    }
}
