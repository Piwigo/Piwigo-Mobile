//
//  ImagePrivacy.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Privacy Levels
public enum pwgPrivacy : Int16, CaseIterable {
    case everybody = 0
    case adminsFamilyFriendsContacts = 1
    case adminsFamilyFriends = 2
    case adminsFamily = 4
    case admins = 8
    case unknown = -1
}

extension pwgPrivacy {
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
    public var name: String {
        switch self {
        case .everybody:
            return String(localized: "privacyLevel_everybody", bundle: piwigoKit,
                          comment: "Everybody")
        case .adminsFamilyFriendsContacts:
            return String(localized: "privacyLevel_adminsFamilyFriendsContacts", bundle: piwigoKit,
                          comment: "Admins, Family, Friends, Contacts")
        case .adminsFamilyFriends:
            return String(localized: "privacyLevel_adminsFamilyFriends", bundle: piwigoKit,
                          comment: "Admins, Family, Friends")
        case .adminsFamily:
            return String(localized: "privacyLevel_adminFamily", bundle: piwigoKit,
                          comment: "Admins, Family")
        case .admins:
            return String(localized: "privacyLevel_admin", bundle: piwigoKit,
                          comment: "Admins")
        default:
            return ""
        }
    }
}
