//
//  UploadUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

public class UploadUtilities: NSObject {

    // For logs
    @nonobjc public static let debugFormatter: DateFormatter = {
        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.ssssss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // - MARK: Constants returning the list of:
    /// - image formats whcih can be converted with iOS
    /// - movie formats which can be converted with iOS
    /// See: https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/system_declared_types
    @nonobjc public static let acceptedImageFormats: String = {
        return "png,heic,heif,tif,tiff,jpg,jpeg,raw,webp,gif,bmp,ico"
    }()
    @nonobjc public static let acceptedMovieFormats: String = {
        return "mov,mpg,mpeg,mpeg2,mp4,avi"
    }()

    // MARK: - File name from PHAsset
    public class func fileName(forImageAsset imageAsset: PHAsset?) -> String {
        var fileName = ""
        
        // Asset resource available?
        if imageAsset != nil {
            // Get file name from image asset
            var resources: [PHAssetResource]? = nil
            if let imageAsset = imageAsset {
                resources = PHAssetResource.assetResources(for: imageAsset)
            }
            // Shared assets may not return resources
            if (resources?.count ?? 0) > 0 {
                for resource in resources ?? [] {
                    if resource.type == .adjustmentData {
                        continue
                    }
                    fileName = resource.originalFilename
                    if (resource.type == .photo) || (resource.type == .video) || (resource.type == .audio) {
                        // We preferably select the original filename
                        break
                    }
                }
            }
            resources?.removeAll(keepingCapacity: false)
        }
        
        // Piwigo 2.10.2 supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
        var utf8mb3Filename = NetworkUtilities.utf8mb3String(from: fileName)

        // If encodedFileName is empty, build one from the current date
        if utf8mb3Filename.count == 0 {
            // No filename => Build filename from creation date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            if let creation = imageAsset?.creationDate {
                utf8mb3Filename = dateFormatter.string(from: creation)
            } else {
                utf8mb3Filename = dateFormatter.string(from: Date())
            }

            // Filename extension required by Piwigo so that it knows how to deal with it
            if imageAsset?.mediaType == .image {
                // Adopt JPEG photo format by default, will be rechecked
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("jpg").lastPathComponent
            } else if imageAsset?.mediaType == .video {
                // Videos are exported in MP4 format
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("mp4").lastPathComponent
            } else if imageAsset?.mediaType == .audio {
                // Arbitrary extension, not managed yet
                utf8mb3Filename = URL(fileURLWithPath: utf8mb3Filename).appendingPathExtension("m4a").lastPathComponent
            }
        }

//        print("=> adopted filename = \(utf8mb3Filename)")
        return utf8mb3Filename
    }
}
