//
//  JSONManager+Root.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 19/12/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import os
import Foundation
import PwgKit

public extension JSONManager {
    
    @concurrent
    func getInfos()  async throws(PwgKitError) {
        // Collect stats from server
        do {
            let pwgData = try await postRequest(withMethod: pwgGetInfos, paramDict: [:],
                                                jsonObjectClientExpectsToReceive: GetInfosJSON.self,
                                                countOfBytesClientExpectsToReceive: 9088)
            // Collect statistics
            // The counts group and transliterate their own digits, so no formatter here.
            var infos = [String]()
            for info in pwgData.data {
                guard let nber = info.value?.intValue else { continue }
                let stat: String?
                switch info.name ?? "" {
                case "nb_elements":     stat = Localized.imageCount(nber)
                case "nb_categories":   stat = Localized.albumCount(nber)
                case "nb_tags":         stat = Localized.tagCount(nber)
                case "nb_users":        stat = Localized.userCount(nber)
                case "nb_groups":       stat = Localized.groupCount(nber)
                case "nb_comments":     stat = Localized.commentCount(nber)
                default:                stat = nil
                }
                if let stat, stat.isEmpty == false { infos.append(stat) }
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
            ServerVars.shared.pwgStatistics = stats
        }
        catch {
            print("Error parsing JSON: \(error)")
        }
    }
}
