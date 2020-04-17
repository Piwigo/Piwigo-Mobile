//
//  NotUploadedYet.swift
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 15/04/2020
//

import Foundation
import Photos

class NotUploadedYet: NSObject {
    
    @objc
    class func getListOfImageNamesThatArentUploaded(forCategory categoryId: Int, withImages imagesInSections: [[PHAsset]]?,
                                                    andSelections selectedSections: [AnyHashable]?,
                                                    onCompletion completion: @escaping (_ imagesNotUploaded: [[PHAsset]]?, _ sectionsToDelete: NSIndexSet?) -> Void) {
        
        CategoriesData.sharedInstance().getCategoryById(categoryId).loadAllCategoryImageData(forProgress: nil, onCompletion: { completed in

            // Collect list of Piwigo images
            let onlineImageData: [PiwigoImageData] = CategoriesData.sharedInstance().getCategoryById(categoryId).imageList

            // Build list of images on Piwigo server
            var onlineImageNamesLookup: [AnyHashable : Any] = [:]
            for imgData in onlineImageData {
                // Filename must not be empty!
                if (imgData.fileName != nil) && (imgData.fileName.count != 0) {

                    // Don't forget that files can be converted (e.g. .mov in iOS device, .mp4 in Piwigo server)
                    imgData.fileName = URL(fileURLWithPath: imgData.fileName).deletingPathExtension().absoluteString

                    // Append to list of Piwigo images
                    onlineImageNamesLookup[imgData.fileName] = imgData.fileName
                }
            }

            // Collect list of local images
            let sectionsToDelete = NSMutableIndexSet()
            var localImagesThatNeedToBeUploaded: [[PHAsset]]? = []
            if ((imagesInSections?.count != selectedSections?.count) || (imagesInSections?.count == 0)) {
                // Return non-modified lists
                completion(imagesInSections, sectionsToDelete)
                return
            }

            // Build list of images which have not already been uploaded to the Piwigo server
            for index in 0..<(imagesInSections?.count ?? 0) {

                // Images in section
                let imagesInSection = imagesInSections?[index]

                // Loop over images of section
                var images: [PHAsset]? = []
                for imageAsset in imagesInSection ?? [] {

                    // Get filename of image asset
                    var imageAssetKey = PhotosFetch.sharedInstance().getFileNameFomImageAsset(imageAsset)

                    // Don't forget that files can be converted (e.g. .mov in iOS device, .mp4 in Piwigo server)
                    imageAssetKey = URL(fileURLWithPath: imageAssetKey!).deletingPathExtension().absoluteString

                    // Compare filenames of local and remote images
                    if imageAssetKey != "" && !(imageAssetKey == "") && onlineImageNamesLookup[imageAssetKey] == nil {
                        // This image doesn't exist in this online category
                        images?.append(imageAsset)
                    }
                }

                // Add section if not empty
                if images?.count != nil {
                    if let images = images {
                        localImagesThatNeedToBeUploaded?.append(images)
                    }
                } else {
                    sectionsToDelete.add(index)
                }
            }

            // Job done
            completion(localImagesThatNeedToBeUploaded, sectionsToDelete)
        })
    }
}
