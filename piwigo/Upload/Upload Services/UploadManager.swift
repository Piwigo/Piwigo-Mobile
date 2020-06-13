//
//  UploadManager.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

let kPiwigoNotificationUploadProgress = "kPiwigoNotificationUploadProgress"

@objc
class UploadManager: NSObject {

    // Singleton
//    static var instance: UploadManager = UploadManager()
//    @objc class func sharedInstance() -> UploadManager {
//        return instance
//    }

    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
    }()


    // MARK: - Background Tasks Instances
    /**
     • Images are prepared with an instance of UploadImagePreparer
     • Videos are prepared with an instance of UploadVideoPreparer
     • Images and videos are transfered with an instance of UploadTransfer
     */
    private lazy var imagePreparer: UploadImagePreparer = {
        let instance : UploadImagePreparer = UploadImagePreparer()
        return instance
    }()

    private lazy var videoPreparer: UploadVideoPreparer = {
        let instance : UploadVideoPreparer = UploadVideoPreparer()
        return instance
    }()

    private lazy var imageTransfer: UploadTransfer = {
        let instance : UploadTransfer = UploadTransfer()
        return instance
    }()

    private lazy var imageFinisher: UploadFinisher = {
        let instance : UploadFinisher = UploadFinisher()
        return instance
    }()

    
    // MARK: - Background Tasks Dispatcher
    /**
     The dispatcher prepares an image for upload and then launch the transfer.
     */
    @objc
    func findNextImageToUpload() {
        print("•••>> findNextImageToUpload… \(String(describing: uploadsProvider.fetchedResultsController.fetchedObjects?.count))")
        
        // Get uploads in queue
        guard let allUploads = uploadsProvider.fetchedResultsController.fetchedObjects else {
            return
        }
        
        // Quit if we are already being uploading
        if allUploads.first(where: { $0.state == .uploading }) != nil {
            return
        }

        // Quit if we are already being preparing a transfer
        if allUploads.first(where: { $0.state == .preparing }) != nil {
            return
        }
        
        // Prepare the next transfer if any
        if let nextUpload = allUploads.first(where: { $0.state == .waiting}) {
            prepare(nextUpload: nextUpload)
        }
    }

    func prepare(nextUpload: Upload) {
        print("•••>> prepare next upload…")

        // Retrieve image asset
        guard let originalAsset = PHAsset.fetchAssets(withLocalIdentifiers: [nextUpload.localIdentifier], options: nil).firstObject else {
            return
        }

        // Determine non-empty unique file name and extension from asset
        nextUpload.fileName = PhotosFetch.sharedInstance().getFileNameFomImageAsset(originalAsset)
        let fileExt = (URL(fileURLWithPath: nextUpload.fileName!).pathExtension).lowercased()
        
        // Set upload properties
        var uploadProperties = UploadProperties.init(localIdentifier: nextUpload.localIdentifier,
                                                     category: Int(nextUpload.category),
                                                     requestDate: nextUpload.requestDate,
                                                     requestState: nextUpload.state,
                                                     requestProgress: nextUpload.requestProgress,
                                                     creationDate: originalAsset.creationDate, fileName: nextUpload.fileName,
                                                     author: nextUpload.author, privacyLevel: nextUpload.privacy,
                                                     title: nextUpload.title,
                                                     comment: nextUpload.comment,
                                                     tags: nextUpload.tags, imageId: NSNotFound)

        // Launch preparation job if file format accepted by Piwigo server
        switch originalAsset.mediaType {
        case .image:
            // Chek that the image format is accepted by the Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains(fileExt) {
                // Image file format accepted by the Piwigo server
                print("   >> preparing photo \(nextUpload.fileName!)…")
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                    // Launch preparation job
                    DispatchQueue.global(qos: .background).async {
                        self.imagePreparer.prepareImage(from: originalAsset, for: uploadProperties) { (updatedUpload, mimeType, imageData, error) in
                            // Error?
                            
                            // Valid data?
                            if let newUpload = updatedUpload, let mime = mimeType, let data = imageData {
                                self.transfer(upload: newUpload, with: mime, imageData: data)
                            }
                        }
                    }
                })
                return
            }
            if Model.sharedInstance().uploadFileTypes.contains("jpg") {
                // Try conversion to JPEG
                if fileExt == "heic" || fileExt == "heif" || fileExt == "avci" {
                    // Will convert HEIC encoded image to JPEG
                    print("   >> preparing photo \(nextUpload.fileName!)…")
                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                        // Launch preparation job
                        DispatchQueue.global(qos: .background).async {
                            self.imagePreparer.prepareImage(from: originalAsset, for: uploadProperties) { (updatedUpload, mimeType, imageData, error) in
                                // Error?
                                
                                // Valid data?
                                if let newUpload = updatedUpload, let mime = mimeType, let data = imageData {
                                    self.transfer(upload: newUpload, with: mime, imageData: data)
                                }
                            }
                        }
                    })
                    return
                }
            }
            // Update state of upload: Image file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToUpload()
            })
//            showError(withTitle: NSLocalizedString("imageUploadError_title", comment: "Image Upload Error"), andMessage: NSLocalizedString("imageUploadError_format", comment: "Sorry, image files with extensions .\(fileExt.uppercased()) and .jpg are not accepted by the Piwigo server."), forRetrying: false, withImage: nextImageToBeUploaded)

        case .video:
            // Chek that the video format is accepted by the Piwigo server
            if Model.sharedInstance().uploadFileTypes.contains(fileExt) {
                // Video file format accepted by the Piwigo server
                print("   >> preparing video \(nextUpload.fileName!)…")
                // Update state of upload
                uploadProperties.requestState = .preparing
                uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                    // Launch preparation job
                    DispatchQueue.global(qos: .background).async {
                        self.videoPreparer.prepare(from: originalAsset, for: uploadProperties) { (updatedUpload, mimeType, imageData, error) in
                            // Error?
                            
                            // Valid data?
                            if let newUpload = updatedUpload, let mime = mimeType, let data = imageData {
                                self.transfer(upload: newUpload, with: mime, imageData: data)
                            }
                        }
                    }
                })
                return
            }
            if Model.sharedInstance().uploadFileTypes.contains("mp4") {
                // Try conversion to MP4
                if fileExt == "mov" {
                    // Will convert MOV encoded video to MP4
                    print("   >> preparing video \(nextUpload.fileName!)…")
                    // Update state of upload
                    uploadProperties.requestState = .preparing
                    uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                        // Launch preparation job
                        DispatchQueue.global(qos: .background).async {
                            self.videoPreparer.convert(from: originalAsset, for: uploadProperties) { (updatedUpload, mimeType, imageData, error) in
                                // Error?
                                
                                // Valid data?
                                if let newUpload = updatedUpload, let mime = mimeType, let data = imageData {
                                    self.transfer(upload: newUpload, with: mime, imageData: data)
                                }
                            }
                        }
                    })
                    return
                }
            }
            // Video file format cannot be accepted by the Piwigo server
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToUpload()
            })
//                showError(withTitle: NSLocalizedString("videoUploadError_title", comment: "Video Upload Error"), andMessage: NSLocalizedString("videoUploadError_format", comment: "Sorry, video files with extension .\(fileExt.uppercased()) are not accepted by the Piwigo server."), forRetrying: false, withImage: uploadToPrepare)

        case .audio:
            // Update state of upload: Not managed by Piwigo iOS yet…
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToUpload()
            })
//            showError(withTitle: NSLocalizedString("audioUploadError_title", comment: "Audio Upload Error"), andMessage: NSLocalizedString("audioUploadError_format", comment: "Sorry, audio files are not supported by Piwigo Mobile yet."), forRetrying: false, withImage: uploadToPrepare)

        case .unknown:
            fallthrough
        default:
            // Update state of upload: Unknown format
            uploadProperties.requestState = .formatError
            uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                // Investigate next upload request
                self.findNextImageToUpload()
            })
        }
    }
    
    func transfer(upload: UploadProperties, with mimeType: String, imageData: Data?) {
        
        // Update state of upload
        var uploadProperties = upload
        uploadProperties.requestState = .uploading
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
            // Launch transfer if possible
            print("•••>> preparing transfer of \(upload.fileName!)…")
            DispatchQueue.global(qos: .background).async {
                self.imageTransfer.uploadImage(imageData, with: uploadProperties, mimeType: mimeType,
               onProgress: { (progress, currentChunk, totalChunks) in
                    let chunkProgress: Float = Float(currentChunk) / Float(totalChunks)
                    let uploadInfo: [String : Any] = ["localIndentifier" : upload.localIdentifier,
                                                      "progressFraction" : chunkProgress]
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationUploadProgress), object: nil, userInfo: uploadInfo)
                    }
                },
               onCompletion: { (task, jsonData, imageParameters) in
                    print("   >> completion: \(String(describing: jsonData))")
                    // Alert the user if no data comes back.
                    guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
//                      completionHandler(TagError.networkUnavailable)
                        return
                    }
                    // Decode the JSON.
                    do {
                        // Decode the JSON into codable type ImagesUploadJSON.
                        let decoder = JSONDecoder()
                        let uploadJSON = try decoder.decode(ImagesUploadJSON.self, from: data)
                        
                        // Piwigo error?
                        let error: NSError
                        if (uploadJSON.errorCode != 0) {
                            error = NSError.init(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                            return
                        }
                        // Get new image ID
                        uploadProperties.imageId = uploadJSON.imagesUpload.image_id!
                        self.finish(upload: uploadProperties, with: imageParameters)
                    } catch {
                        // Alert the user if data cannot be digested.
//                      completionHandler(TagError.wrongDataFormat)
                        return
                    }
                },
                onFailure: { (task, error) in
                    if let error = error {
                        print("   >> ERROR IMAGE UPLOAD: \(error)")
                    }
                })
            }
        })
    }
    
    func finish(upload: UploadProperties, with imageParameters: [String:String] ) -> (Void) {
        // Update state of upload
        var uploadProperties = upload
        uploadProperties.requestState = .finishing

        // Finish the job by setting image parameters…
        uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
            print("   >> finishing...")
            // Set image properties
            ImageService.setImageInfoForImageWithId(uploadProperties.imageId,
                withInformation: imageParameters,
                onProgress:nil,
                onCompletion: { (task, jsonData) in
                    print("   >> completion: \(String(describing: jsonData))")
                    // Alert the user if no data comes back.
                    guard let data = try? JSONSerialization.data(withJSONObject:jsonData ?? "") else {
//                                  completionHandler(TagError.networkUnavailable)
                        return
                    }
                    // Decode the JSON.
                    do {
                        // Decode the JSON into codable type ImagesUploadJSON.
                        let decoder = JSONDecoder()
                        let uploadJSON = try decoder.decode(ImageSetInfoJSON.self, from: data)
                        
                        // Piwigo error?
                        let error: NSError
                        if (uploadJSON.errorCode != 0) {
                            error = NSError.init(domain: "Piwigo", code: uploadJSON.errorCode, userInfo: [NSLocalizedDescriptionKey : uploadJSON.errorMessage])
                            return
                        }
                    } catch {
                        // Alert the user if data cannot be digested.
//                      completionHandler(TagError.wrongDataFormat)
                        return
                    }
                    // Image successfully uploaded
                    uploadProperties.requestState = .uploaded
                    self.uploadsProvider.updateRecord(with: uploadProperties, completionHandler: { _ in
                        print("   >> complete ;-)")
                        // Increment number of images in category
                        CategoriesData.sharedInstance().getCategoryById(upload.category).incrementImageSizeByOne()

                        // Read image information and update cache
                        ImageService.getImageInfo(byId: uploadProperties.imageId, andAddImageToCache: true, listOnCompletion: { task, imageData in
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationCategoryDataUpdated), object: nil, userInfo: nil)
                            }
                        }, onFailure: { task, error in
                            // NOP — Not a big issue
                        })
                        
                        // Update number of left uploads
                        let nberOfUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects?.count ?? 0
                        let completedUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects?.map({ $0.requestSate == Int16(kPiwigoUploadState.uploaded.rawValue) ? 1 : 0}).reduce(0, +) ?? 0
                        let uploadInfo: [String : Int] = ["leftUploads" : nberOfUploads - completedUploads]
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name(kPiwigoNotificationLeftUploads), object: nil, userInfo: uploadInfo)
                        }

                        // Any other image in upload queue?
                        self.findNextImageToUpload()
                        return
                    })
                },
                onFailure: { (task, error) in
                })
        })
    }
}
