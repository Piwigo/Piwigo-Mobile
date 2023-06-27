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
    case count = 5
    case unknown = -1
}

extension pwgPrivacy {
    public var name: String {
        switch self {
        case .everybody:
            return NSLocalizedString("privacyLevel_everybody", comment: "Everybody")
        case .adminsFamilyFriendsContacts:
            return NSLocalizedString("privacyLevel_adminsFamilyFriendsContacts", comment: "Admins, Family, Friends, Contacts")
        case .adminsFamilyFriends:
            return NSLocalizedString("privacyLevel_adminsFamilyFriends", comment: "Admins, Family, Friends")
        case .adminsFamily:
            return NSLocalizedString("privacyLevel_adminFamily", comment: "Admins, Family")
        case .admins:
            return NSLocalizedString("privacyLevel_admin", comment: "Admins")
        default:
            return ""
        }
    }
}
