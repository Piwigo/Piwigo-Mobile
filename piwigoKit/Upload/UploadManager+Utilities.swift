//
//  UploadUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import MobileCoreServices
import Photos

extension UploadManager {
    
    // MARK: - Upload File Utilities
    /// - Get URL of final upload file to be stored into Piwigo/Uploads directory
    /// - Delete existing file if demanded (failed previous attempt?)
    public func getUploadFileURL(from upload: Upload, withSuffix suffix: String = "",
                                  deleted deleteIt: Bool = false) -> URL {
        // File name of image data to be stored into Piwigo/Uploads directory
        let fileName = upload.localIdentifier.replacingOccurrences(of: "/", with: "-").appending(suffix)
        if fileName.count ==  0 { fatalError("!!!! No Upload Filename !!!!")}
        let fileURL = applicationUploadsDirectory.appendingPathComponent(fileName)
        
        // Should we delete it?
        if deleteIt {
            // Deletes temporary image file if it exists (incomplete previous attempt?)
            do { try FileManager.default.removeItem(at: fileURL) } catch { }
        }
        
        return fileURL
    }

    /// - Rename Upload file if needed
    /// - Get MD5 checksum and MIME type
    /// - Update upload session counter
    /// -> return updated upload properties w/ or w/o error
    public func finalizeImageFile(atURL originalFileURL: URL, with upload: Upload,
                                  completion: @escaping () -> Void,
                                  failure: @escaping (Error?) -> Void) {

        // File name of image data to be stored into Piwigo/Uploads directory
        let fileURL = getUploadFileURL(from: upload)

        // Should we rename the file to adopt the Upload Manager convention?
        if originalFileURL != fileURL {
            // Deletes temporary Upload file if it exists (incomplete previous attempt?)
            do { try FileManager.default.removeItem(at: fileURL) } catch { }

            // Adopts Upload filename convention (e.g. removes the "-original" suffix)
            do {
                try FileManager.default.moveItem(at: originalFileURL, to: fileURL)
            }
            catch {
                // Update upload request
                failure(error)
            }
        }
        
        // Determine MD5 checksum of image file to upload
        let error: NSError?
        (upload.md5Sum, error) = fileURL.MD5checksum()
        print("\(debugFormatter.string(from: Date())) > MD5: \(String(describing: upload.md5Sum))")
        if error != nil {
            // Could not determine the MD5 checksum
            failure(error)
            return
        }

        // Get MIME type from file extension
        let fileExt = (URL(fileURLWithPath: upload.fileName).pathExtension).lowercased()
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt as NSString, nil)?.takeRetainedValue() else {
            let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            failure(error)
            return
        }
        guard let mimeType = (UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue()) as String? else  {
            let error = NSError(domain: "Piwigo", code: 0, userInfo: [NSLocalizedDescriptionKey : UploadError.missingAsset.localizedDescription])
            failure(error)
            return
        }
        print("\(debugFormatter.string(from: Date())) > MIME type: \(String(describing: mimeType))")
        upload.mimeType = mimeType

        // Done -> append file size to counter
        countOfBytesPrepared += UInt64(fileURL.fileSize)
        completion()
    }

    /// - Delete Upload files w/ or w/o prefix
    public func deleteFilesInUploadsDirectory(withPrefix prefix: String = "") -> Void {
        let fileManager = FileManager.default
        do {
            // Get list of files
            var filesToDelete = try fileManager.contentsOfDirectory(at: self.applicationUploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            if prefix.isEmpty == false {
                // Will delete files with given prefix only
                filesToDelete.removeAll(where: { !$0.lastPathComponent.hasPrefix(prefix) })
            }

            // Delete files
            for file in filesToDelete {
                try fileManager.removeItem(at: file)
            }
            
            // Release memory
            filesToDelete.removeAll()

            // Get uploads to complete in queue
            // Considers only uploads to the server to which the user is logged in
            let states: [pwgUploadState] = [.waiting, .preparing, .preparingError,
                                            .preparingFail, .formatError, .prepared,
                                            .uploading, .uploadingError, .uploadingFail, .uploaded,
                                            .finishing, .finishingError]
            // Update app badge and Upload button in root/default album
            UploadManager.shared.nberOfUploadsToComplete = uploadProvider.getRequests(inStates: states).0.count

            // For debugging
//            let leftFiles = try fileManager.contentsOfDirectory(at: self.applicationUploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//            print("\(debugFormatter.string(from: Date())) > Remaining files in cache: \(leftFiles)")
        } catch {
            print("\(debugFormatter.string(from: Date())) > could not clear the Uploads folder: \(error)")
        }
    }

}

// MARK: - For checking operation queue
/// The name/description of the current queue (Operation or Dispatch), if that can be found. Else, the name/description of the thread.
public func queueName() -> String {
    if let currentOperationQueue = OperationQueue.current {
        if let currentDispatchQueue = currentOperationQueue.underlyingQueue {
            return "dispatch queue: \(currentDispatchQueue.label.nonEmpty ?? currentDispatchQueue.description)"
        }
        else {
            return "operation queue: \(currentOperationQueue.name?.nonEmpty ?? currentOperationQueue.description)"
        }
    }
    else {
        let currentThread = Thread.current
        return "thread: \(currentThread.name?.nonEmpty ?? currentThread.description)"
    }
}

public extension String {
    /// Returns this string if it is not empty, else `nil`.
    var nonEmpty: String? {
        if self.isEmpty {
            return nil
        }
        else {
            return self
        }
    }
}
