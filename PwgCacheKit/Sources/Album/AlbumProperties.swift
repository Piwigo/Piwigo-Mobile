//
//  AlbumProperties.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 07/03/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

/**
 A struct for managing album data
*/
public struct AlbumProperties: Sendable
{
    public let pwgID: Int32                         // Piwigo album ID
    public var name: String                         // Album name
    public var status: pwgAlbumStatus               // See pwgAlbumStatus enum
    public var comment: AttributedString            // Plain version of the description
    public var commentHTML: AttributedString        // HTML version of the description
    public var pageUrl: URL?                        // Album page URL
    public var query: String                        // Search query

    public var upperIds: String                     // Parent album IDs

    public var nbImages: Int64                      // Number of images in album
    public var totalNbImages: Int64                 // Number of images in album and sub-albums
    public var images: [Int64]                      // List of images IDs
    public var imageSort: String                    // How images are sorted on the server
    public var currentCounter: Int64                // Used to rename images before upload
    public var dateGetImages: TimeInterval          // When images were fetched

    public var shareUrl: URL?                       // URL of the share, nil when the album is not shared
    public var shareCreationDate: TimeInterval      // When the share was created
    public var sharedByID: Int16                    // Piwigo ID of the user who created the share
    public var sharedByName: String                 // Username of the user who created the share

    public var URIstr: String                       // URI string representation
    public var userURIstr: String                   // URI string representation of the associated User instance
}

extension AlbumProperties
{
    public init(withID pwgID: Int32) {
        self.init(pwgID: pwgID, name: "", status: .publicStatus,
                  comment: AttributedString(), commentHTML: AttributedString(),
                  pageUrl: nil,
                  query: "",

                  upperIds: "",
        
                  nbImages: 0, totalNbImages: 0, images: [],
                  imageSort: "", currentCounter: Int64.zero,
                  dateGetImages: Date.distantPast.timeIntervalSinceReferenceDate,

                  shareUrl: nil,
                  shareCreationDate: DateUtilities.unknownDateInterval,
                  sharedByID: Int16.zero, sharedByName: "",

                  URIstr: "",
                  userURIstr: ""
        )
    }
}
