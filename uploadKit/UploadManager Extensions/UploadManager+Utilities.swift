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
import piwigoKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Upload File Utilities
    // Returns the URL of final upload file to be stored into Piwigo/Uploads directory
    // and delete existing file if demanded (case of a failed previous attempt)
    // ******************************************************************************************************
    // * declared "nonisolated" because the compiler returns:
    // * Pattern that the region based isolation checker does not understand how to check. Please file a bug
    // ******************************************************************************************************
    nonisolated func getUploadFileURL(from localIdentifier: String, withSuffix suffix: String = "",
                                      creationDate: TimeInterval, deleted deleteIt: Bool = false) -> URL {
        // File name of image data to be stored into Piwigo/Uploads directory
        var fileName = ""
        if #available(iOS 16.0, *) {
            fileName = localIdentifier.replacing("/", with: "-")
        } else {
            // Fallback on earlier versions
            fileName = localIdentifier.replacingOccurrences(of: "/", with: "-")
        }
        if fileName.isEmpty {
            fileName = "file-".appending(String(Int64(creationDate)))
        }
        fileName.append(suffix)
        let fileURL = DataDirectories.appUploadsDirectory.appendingPathComponent(fileName)
        
        // Should we delete it?
        if deleteIt {
            // Deletes temporary image file if it exists (incomplete previous attempt?)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        return fileURL
    }
    
    /// - Delete Upload files w/ or w/o prefix
    public func deleteFilesInUploadsDirectory(withPrefix prefix: String = "") {
        let fileManager = FileManager.default
        do {
            // Get list of files
            let uploadsDirectory = DataDirectories.appUploadsDirectory
            var filesToDelete = try fileManager.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
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
            
            // For debugging
//            let leftFiles = try fileManager.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
//            debugPrint("\(dbg()) Remaining files in cache: \(leftFiles)")
        } catch {
            UploadManager.logger.notice("Could not clear the Uploads folder: \(error)")
        }
    }
}
