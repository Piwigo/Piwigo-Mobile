//
//  sharealbum.errors.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2026.
//

import Foundation

// MARK: Piwigo Error Codes
/// Error code returned in the "err" field by sharealbum.getInfo, sharealbum.cancel
/// and sharealbum.renew when the album is not shared.
/// The plugin checks whether an album is shared before checking that this album still exists,
/// so a 404 error returned by these methods always means that the album has no share.
/// This is a valid state, not an error.
public let kShareAlbumNotSharedError = 404

/// Error code returned in the "err" field by sharealbum.create when the album is already shared,
/// which happens when a share was created with another device since the last sharealbum.getList.
/// This is a valid state, not an error, but sharealbum.create does not return the existing share:
/// the share URL must then be retrieved with sharealbum.getInfo.
public let kShareAlbumAlreadySharedError = 409

/// Error code returned in the "err" field by every sharealbum method when the user is
/// neither an administrator nor a member of the "sharealbum_powerusers" group.
/// No method tells whether the user is allowed beforehand, so the first call is the probe.
public let kShareAlbumForbiddenError = 403
