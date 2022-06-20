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

@interface Model : NSObject

+(Model*)sharedInstance;
-(void)readFromDisk;

@end
