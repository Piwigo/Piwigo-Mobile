//
//  JSONManager+Images.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 27/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    @concurrent
    func getIDofImage(withMD5 md5sum: String) async throws(PwgKitError) -> Int64? {
        // Prepare parameters
        let paramDict: [String : Any] = ["md5sum_list": md5sum]
        
        let pwgData = try await postRequest(withMethod: pwgImagesExist, paramDict: paramDict,
                                            jsonObjectClientExpectsToReceive: ImagesExistJSON.self,
                                            countOfBytesClientExpectsToReceive: pwgImagesExistBytes)
        
        if let imageID = pwgData.data.first(where: {$0.md5sum == md5sum})?.imageID {
            return imageID
        } else {
            return nil
        }
    }
    
    @concurrent
    func getInfos(forID imageId: Int64) async throws(PwgKitError) -> ImagesGetInfo {
        // Prepare parameters
        let paramsDict: [String : Any] = ["image_id" : imageId]
        
        // Launch request
        let pwgData = try await postRequest(withMethod: pwgImagesGetInfo, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: ImagesGetInfoJSON.self,
                                            countOfBytesClientExpectsToReceive: 50000)
        return pwgData.data
    }
    
    @concurrent
    func setInfos(with paramsDict: [String: Any]) async throws(PwgKitError) {
        // Prepare parameters
        let pwgData = try await postRequest(withMethod: pwgImagesSetInfo, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: ImagesSetInfoJSON.self,
                                            countOfBytesClientExpectsToReceive: pwgImagesSetInfoBytes)
        
        if pwgData.success == false {
            // Could not set image parameters
            throw PwgKitError.unexpectedError
        }
    }
    
    @concurrent
    func setCategory(_ albumID: Int32, forImageIDs listOfImageIds: [Int64],
                     withAction action: pwgImagesSetCategoryAction) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["image_id"    : listOfImageIds,
                                          "category_id" : albumID,
                                          "action"      : action.rawValue,
                                          "pwg_token"   : NetworkVars.shared.pwgToken]
        
        // Associated/dissociated/moved images
        _ = try await postRequest(withMethod: pwgImagesSetCategory, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: ImagesSetCategoryJSON.self,
                                  countOfBytesClientExpectsToReceive: pwgImagesSetCategoryBytes)
    }
    
    @concurrent
    func delete(_ images: Set<Image>) async throws(PwgKitError) {
        // Prepare parameters
        let listOfImageIds: [Int64] = images.map({ $0.pwgID })
        let paramsDict: [String : Any] = ["image_id"  : listOfImageIds,
                                          "pwg_token" : NetworkVars.shared.pwgToken]
        
        _ = try await postRequest(withMethod: pwgImagesDelete, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: ImagesDeleteJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
        // Images deleted successfully
        /// We may check here that the number returned matches the number of images to delete
        /// and return an error to the user.
    }
    
    @concurrent
    func processImages(withIds imageIds: Int64, inCategory categoryId: Int32) async throws(PwgKitError) {
        // Prepare parameters
        let paramDict: [String : Any] = ["image_id": "\(NSNumber(value: imageIds))",
                                         "pwg_token": NetworkVars.shared.pwgToken,
                                         "category_id": "\(NSNumber(value: categoryId))"]
        
        // Empty lounge
        let pwgData = try await postRequest(withMethod: pwgImagesUploadCompleted, paramDict: paramDict,
                                            jsonObjectClientExpectsToReceive: ImagesUploadCompletedJSON.self,
                                            countOfBytesClientExpectsToReceive: 2500)
        // Successful?
        if pwgData.success == false {
            throw .emptyingLoungeFailed
        }
    }
}
