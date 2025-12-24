//
//  JSONManager+Root.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension JSONManager {
    
    func getInfos() {
        // Collect stats from server
        postRequest(withMethod: pwgGetInfos, paramDict: [:],
                    jsonObjectClientExpectsToReceive: GetInfosJSON.self,
                    countOfBytesClientExpectsToReceive: 8448) { result in
            switch result {
            case .success(let pwgData):
                // Collect statistics
                var infos = [String]()
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                for info in pwgData.data {
                    guard let nber = info.value?.intValue else { continue }
                    switch info.name ?? "" {
                    case "nb_elements":
                        if let nberPhotos = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberImages = nber > 1 ?
                            String(format: String(localized: "severalImagesCount", bundle: piwigoKit, comment: "%@ photos"), nberPhotos) :
                            String(format: String(localized: "singleImageCount", bundle: piwigoKit, comment: "%@ photo"), nberPhotos)
                            if nberImages.isEmpty == false { infos.append(nberImages) }
                        }
                    case "nb_categories":
                        if let nberCats = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberCategories = nber > 1 ?
                            String(format: String(localized: "severalAlbumsCount", bundle: piwigoKit, comment: "%@ albums"), nberCats) :
                            String(format: String(localized: "singleAlbumCount", bundle: piwigoKit, comment: "%@ album"), nberCats)
                            if nberCategories.isEmpty == false { infos.append(nberCategories) }
                        }
                    case "nb_tags":
                        if let nberTags = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberTags = nber > 1 ?
                            String(format: String(localized: "severalTagsCount", bundle: piwigoKit, comment: "%@ tags"), nberTags) :
                            String(format: String(localized: "singleTagCount", bundle: piwigoKit, comment: "%@ tag"), nberTags)
                            if nberTags.isEmpty == false { infos.append(nberTags) }
                        }
                    case "nb_users":
                        if let nberUsers = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberUsers = nber > 1 ?
                            String(format: String(localized: "severalUsersCount", bundle: piwigoKit, comment: "%@ users"), nberUsers) :
                            String(format: String(localized: "singleUserCount", bundle: piwigoKit, comment: "%@ user"), nberUsers)
                            if nberUsers.isEmpty == false { infos.append(nberUsers) }
                        }
                    case "nb_groups":
                        if let nberGroups = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberGroups = nber > 1 ?
                            String(format: String(localized: "severalGroupsCount", bundle: piwigoKit, comment: "%@ groups"), nberGroups) :
                            String(format: String(localized: "singleGroupCount", bundle: piwigoKit, comment: "%@ group"), nberGroups)
                            if nberGroups.isEmpty == false { infos.append(nberGroups) }
                        }
                    case "nb_comments":
                        if let nberComments = numberFormatter.string(from: NSNumber(value: nber)) {
                            let nberComments = nber > 1 ?
                            String(format: String(localized: "severalCommentsCount", bundle: piwigoKit, comment: "%@ comments"), nberComments) :
                            String(format: String(localized: "singleCommentCount", bundle: piwigoKit, comment: "%@ comment"), nberComments)
                            if nberComments.isEmpty == false { infos.append(nberComments) }
                        }
                    default:
                        break
                    }
                }

                // Update statistics stored in cache
                var stats = ""
                for info in infos {
                    if stats.isEmpty {
                        stats.append(info)
                    } else {
                        stats.append(" | " + info)
                    }
                }
                NetworkVars.shared.pwgStatistics = stats

            case .failure(let error):
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                /// -> nothing presented in the footer
                debugPrint(error.localizedDescription)
            }
        }
    }
}
