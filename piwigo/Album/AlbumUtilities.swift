//
//  AlbumUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

@objc
class AlbumUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    @objc
    class func setRepresentativeOf(category categoryId: Int, with imageData: PiwigoImageData,
                                   completion: @escaping () -> Void,
                                   failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : categoryId,
                                          "image_id"    : imageData.imageId]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: kPiwigoCategoriesSetRepresentative, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesSetRepresentativeJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesSetRepresentativeJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesSetRepresentativeJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                    errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album thumbnail successfully set ▶ update catagory in cache
                    if let category = CategoriesData.sharedInstance().getCategoryById(categoryId) {
                        category.albumThumbnailId = imageData.imageId
                        category.albumThumbnailUrl = imageData.thumbPath
                        CategoriesData.sharedInstance().updateCategories([category])
                    }
                    completion()
                }
                else {
                    // Could not delete images
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }


    // MARK: - Album Collections
    @objc
    class func footerLegend(for nberOfImages: Int) -> String {
        var legend = ""
        if nberOfImages == NSNotFound {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if nberOfImages == 0 {
            // Not loading and no images
            legend = NSLocalizedString("noImages", comment:"No Images")
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: nberOfImages)) {
                let format:String = nberOfImages > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
        }
        return legend
    }
}
