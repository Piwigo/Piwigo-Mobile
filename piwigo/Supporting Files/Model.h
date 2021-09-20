//
//  Model.h
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "AFAutoPurgingImageCache.h"

FOUNDATION_EXPORT CGFloat const kPiwigoPadSubViewWidth;
FOUNDATION_EXPORT CGFloat const kPiwigoPadSettingsWidth;

FOUNDATION_EXPORT NSTimeInterval const k1WeekInDays;
FOUNDATION_EXPORT NSTimeInterval const k2WeeksInDays;
FOUNDATION_EXPORT NSTimeInterval const k3WeeksInDays;

FOUNDATION_EXPORT NSInteger const kDelayPiwigoHUD;

@class PHPhotoLibrary;

typedef enum NSInteger {
    kPiwigoImageSizeSquare,
    kPiwigoImageSizeThumb,
    kPiwigoImageSizeXXSmall,
    kPiwigoImageSizeXSmall,
    kPiwigoImageSizeSmall,
    kPiwigoImageSizeMedium,
    kPiwigoImageSizeLarge,
    kPiwigoImageSizeXLarge,
    kPiwigoImageSizeXXLarge,
    kPiwigoImageSizeFullRes,
    kPiwigoImageSizeEnumCount
} kPiwigoImageSize;

typedef enum {
    kPiwigoSortObjcNameAscending,               // Photo title, A → Z
    kPiwigoSortObjcNameDescending,              // Photo title, Z → A
    
    kPiwigoSortObjcDateCreatedDescending,       // Date created, new → old
    kPiwigoSortObjcDateCreatedAscending,        // Date created, old → new
    
    kPiwigoSortObjcDatePostedDescending,        // Date posted, new → old
    kPiwigoSortObjcDatePostedAscending,         // Date posted, old → new
    
    kPiwigoSortObjcFileNameAscending,           // File name, A → Z
    kPiwigoSortObjcFileNameDescending,          // File name, Z → A
    
    kPiwigoSortObjcRatingScoreDescending,       // Rating score, high → low
    kPiwigoSortObjcRatingScoreAscending,        // Rating score, low → high

    kPiwigoSortObjcVisitsDescending,            // Visits, high → low
    kPiwigoSortObjcVisitsAscending,             // Visits, low → high

    kPiwigoSortObjcManual,                      // Manual order
    kPiwigoSortObjcRandom,                      // Random order
//    kPiwigoSortObjcVideoOnly,
//    kPiwigoSortObjcImageOnly,
    
    kPiwigoSortObjcCount
} kPiwigoSortObjc;

typedef enum {
	kPiwigoPrivacyObjcEverybody = 0,
	kPiwigoPrivacyObjcAdminsFamilyFriendsContacts = 1,
	kPiwigoPrivacyObjcAdminsFamilyFriends = 2,
	kPiwigoPrivacyObjcAdminsFamily = 4,
	kPiwigoPrivacyObjcAdmins = 8,
	kPiwigoPrivacyObjcCount = 5,
    kPiwigoPrivacyObjcUnknown = -1
} kPiwigoPrivacyObjc;

#define kPiwigoPrivacyString(enum) [@[@"Everybody", @"Admins, Family, Friends, Contacts", @"Admins, Family, Friends", @"3: not assigned", @"Admins, Family", @"5: Count", @"6: not assigned", @"7: not assigned", @"Admins"] objectAtIndex:enum]

typedef enum {
    kPiwigoCategorySelectActionNone,
    kPiwigoCategorySelectActionSetDefaultAlbum,
    kPiwigoCategorySelectActionMoveAlbum,
    kPiwigoCategorySelectActionSetAlbumThumbnail,
    kPiwigoCategorySelectActionSetAutoUploadAlbum,
    kPiwigoCategorySelectActionCopyImage,
    kPiwigoCategorySelectActionMoveImage,
    kPiwigoCategorySelectActionCopyImages,
    kPiwigoCategorySelectActionMoveImages
} kPiwigoCategorySelectAction;

typedef enum {
    kPiwigoCategoryTableCellButtonStateNone = 0,
    kPiwigoCategoryTableCellButtonStateShowSubAlbum = 1,
    kPiwigoCategoryTableCellButtonStateHideSubAlbum = 2
} kPiwigoCategoryTableCellButtonState;

@interface Model : NSObject

+(Model*)sharedInstance;
-(void)readFromDisk;

@end
