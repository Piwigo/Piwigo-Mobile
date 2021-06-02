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
    kPiwigoSortNameAscending,               // Photo title, A → Z
    kPiwigoSortNameDescending,              // Photo title, Z → A
    
    kPiwigoSortDateCreatedDescending,       // Date created, new → old
    kPiwigoSortDateCreatedAscending,        // Date created, old → new
    
    kPiwigoSortDatePostedDescending,        // Date posted, new → old
    kPiwigoSortDatePostedAscending,         // Date posted, old → new
    
    kPiwigoSortFileNameAscending,           // File name, A → Z
    kPiwigoSortFileNameDescending,          // File name, Z → A
    
    kPiwigoSortRatingScoreDescending,       // Rating score, high → low
    kPiwigoSortRatingScoreAscending,        // Rating score, low → high

    kPiwigoSortVisitsDescending,            // Visits, high → low
    kPiwigoSortVisitsAscending,             // Visits, low → high

    kPiwigoSortManual,                      // Manual order
    kPiwigoSortRandom,                      // Random order
//    kPiwigoSortVideoOnly,
//    kPiwigoSortImageOnly,
    
    kPiwigoSortCount
} kPiwigoSort;

typedef enum {
	kPiwigoPrivacyEverybody = 0,
	kPiwigoPrivacyAdminsFamilyFriendsContacts = 1,
	kPiwigoPrivacyAdminsFamilyFriends = 2,
	kPiwigoPrivacyAdminsFamily = 4,
	kPiwigoPrivacyAdmins = 8,
	kPiwigoPrivacyCount = 5,
    kPiwigoPrivacyUnknown = INT_MAX
} kPiwigoPrivacy;

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
-(NSString *)getNameForPrivacyLevel:(kPiwigoPrivacy)privacyLevel;

@end
