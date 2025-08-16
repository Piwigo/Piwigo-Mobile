//
//  PwgSession+Root.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 19/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation

public extension PwgSession {
    
    func getInfos() {
        // Collect stats from server
        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgGetInfos, paramDict: [:],
                                jsonObjectClientExpectsToReceive: GetInfosJSON.self,
                                countOfBytesClientExpectsToReceive: 8448) { result in
            switch result {
            case .success(let jsonData):
                // Decode the JSON object and retrieve statistics.
                do {
                    // Decode the JSON into codable type GetInfosJSON.
                    let decoder = JSONDecoder()
                    let pwgData = try decoder.decode(GetInfosJSON.self, from: jsonData)
                    
                    // Piwigo error?
                    if pwgData.errorCode != 0 {
#if DEBUG
                        let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                        debugPrint(error)
#endif
                        return
                    }
                    
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
                                String(format: NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberPhotos) :
                                String(format: NSLocalizedString("singleImageCount", comment: "%@ photo"), nberPhotos)
                                if nberImages.isEmpty == false { infos.append(nberImages) }
                            }
                        case "nb_categories":
                            if let nberCats = numberFormatter.string(from: NSNumber(value: nber)) {
                                let nberCategories = nber > 1 ?
                                String(format: NSLocalizedString("severalAlbumsCount", comment: "%@ albums"), nberCats) :
                                String(format: NSLocalizedString("singleAlbumCount", comment: "%@ album"), nberCats)
                                if nberCategories.isEmpty == false { infos.append(nberCategories) }
                            }
                        case "nb_tags":
                            if let nberTags = numberFormatter.string(from: NSNumber(value: nber)) {
                                let nberTags = nber > 1 ?
                                String(format: NSLocalizedString("severalTagsCount", comment: "%@ tags"), nberTags) :
                                String(format: NSLocalizedString("singleTagCount", comment: "%@ tag"), nberTags)
                                if nberTags.isEmpty == false { infos.append(nberTags) }
                            }
                        case "nb_users":
                            if let nberUsers = numberFormatter.string(from: NSNumber(value: nber)) {
                                let nberUsers = nber > 1 ?
                                String(format: NSLocalizedString("severalUsersCount", comment: "%@ users"), nberUsers) :
                                String(format: NSLocalizedString("singleUserCount", comment: "%@ user"), nberUsers)
                                if nberUsers.isEmpty == false { infos.append(nberUsers) }
                            }
                        case "nb_groups":
                            if let nberGroups = numberFormatter.string(from: NSNumber(value: nber)) {
                                let nberGroups = nber > 1 ?
                                String(format: NSLocalizedString("severalGroupsCount", comment: "%@ groups"), nberGroups) :
                                String(format: NSLocalizedString("singleGroupCount", comment: "%@ group"), nberGroups)
                                if nberGroups.isEmpty == false { infos.append(nberGroups) }
                            }
                        case "nb_comments":
                            if let nberComments = numberFormatter.string(from: NSNumber(value: nber)) {
                                let nberComments = nber > 1 ?
                                String(format: NSLocalizedString("severalCommentsCount", comment: "%@ comments"), nberComments) :
                                String(format: NSLocalizedString("singleCommentCount", comment: "%@ comment"), nberComments)
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
                }
                catch let error {
                    // Data cannot be digested
#if DEBUG
                    debugPrint(error.localizedDescription)
#endif
                }

            case .failure:
                /// - Network communication errors
                /// - Returned JSON data is empty
                /// - Cannot decode data returned by Piwigo server
                /// -> nothing presented in the footer
                break
            }
        }
    }
}
