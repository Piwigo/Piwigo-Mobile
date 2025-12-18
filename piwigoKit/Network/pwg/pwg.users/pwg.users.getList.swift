//
//  pwg.users.getList.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 26/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public let pwgUsersGetList = "pwg.users.getList"

// MARK: Piwigo JSON Structures
public struct UsersGetListJSON: Decodable {

    public var status: String?
    public var paging: PageData?
    public var users = [UsersGetInfo]()
    public var totalCount: Int?
    
    private enum RootCodingKeys: String, CodingKey {
        case status = "stat"
        case data = "result"
        case errorCode = "err"
        case errorMessage = "message"
    }

    private enum ResultCodingKeys: String, CodingKey {
        case paging, users, totalCount = "total_count"
    }

    public init(from decoder: Decoder) throws
    {
        // Root container keyed by RootCodingKeys
        let rootContainer = try decoder.container(keyedBy: RootCodingKeys.self)
        
        // Status returned by Piwigo
        status = try rootContainer.decodeIfPresent(String.self, forKey: .status)
        if (status == "ok")
        {
            // Result container keyed by ResultCodingKeys
            let resultContainer = try rootContainer.nestedContainer(keyedBy: ResultCodingKeys.self, forKey: .data)
//            dump(resultContainer)
            
            // Paging data
            paging = try resultContainer.decode(PageData.self, forKey: .paging)
            
            // Images data
            users = try resultContainer.decode([UsersGetInfo].self, forKey: .users)
        }
        else if (status == "fail")
        {
            // Retrieve Piwigo server error
            let errorCode = try rootContainer.decode(Int.self, forKey: .errorCode)
            let errorMessage = try rootContainer.decode(String.self, forKey: .errorMessage)
            let pwgError = PwgKitError.pwgError(code: errorCode, msg: errorMessage)
            let context = DecodingError.Context(codingPath: [], debugDescription: reason, underlyingError: pwgError)
            throw DecodingError.dataCorrupted(context)
        }
        else {
            // Unexpected Piwigo server error
            let pwgError = PwgKitError.unexpectedError
            let context = DecodingError.Context(codingPath: [], debugDescription: reason, underlyingError: pwgError)
            throw DecodingError.dataCorrupted(context)
        }
    }
}

public struct UsersGetInfo: Decodable
{
    public let id: Int16?                           // 1
    public let userName: String?                    // "Eddy"
    public let email: String?                       // "admin@piwigo.org"
    public let userStatus: String?                  // "webmaster"
    public var privacyLevel: String?                // "8"
    public let language: String?                    // "en_UK"
    public let theme: String?                       // "bootstrap_darkroom"
    public let imagesPerPage: StringOrInt?          // "24"
    public let recentPeriod: StringOrInt?           // "10"
    public let expandAlbums: StringOrBool?          // "false"
    public let showNberOfComments: StringOrBool?    // "false"
    public let showNberOfVisits: StringOrBool?      // "false"
    public let enabledHigh: StringOrBool?           // "true"
    public let registrationDate: String?            // "2017-08-31 22:15:45"
    public let lastVisit: String?                   // "2025-03-26 19:03:25"
    public let lastVisitFromHistory: StringOrBool?  // "false"
    public let groups: [Int16]?                     // [1, 2]
    public let registrationDateStr: String?         // "31 August 2017"
    public let registrationDateSince: String?       // "7 years 6 months ago"
    public let lastVisitStr: String?                // "26 March 2025"
    public let lastVisitSince: String?              // "1 minute ago"

    public enum CodingKeys: String, CodingKey {
        case id = "id"
        case userName = "username"
        case email = "email"
        case userStatus = "status"
        case privacyLevel = "level"
        case language = "language"
        case theme = "theme"
        case imagesPerPage = "nb_image_page"
        case recentPeriod = "recent_period"
        case expandAlbums = "expand"
        case showNberOfComments = "show_nb_comments"
        case showNberOfVisits = "show_nb_hits"
        case enabledHigh = "enabled_high"
        case registrationDate = "registration_date"
        case lastVisit = "last_visit"
        case lastVisitFromHistory = "last_visit_from_history"
        case groups = "groups"
        case registrationDateStr = "registration_date_string"
        case registrationDateSince = "registration_date_since"
        case lastVisitStr = "last_visit_string"
        case lastVisitSince = "last_visit_since"
    }
}
