//
//  Model.h
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "CategorySortViewController.h"

@class PHPhotoLibrary;

typedef enum {
	kPiwigoPrivacyEverybody = 0,
	kPiwigoPrivacyAdminsFamilyFriendsContacts = 1,
	kPiwigoPrivacyAdminsFamilyFriends = 2,
	kPiwigoPrivacyAdminsFamily = 4,
	kPiwigoPrivacyAdmins = 8,
	kPiwigoPrivacyCount = 5
} kPiwigoPrivacy;

#define kPiwigoPrivacyString(enum) [@[@"Everybody", @"Admins, Family, Friends, Contacts", @"Admins, Family, Friends", @"3: not assigned", @"Admins, Family", @"5: Count", @"6: not assigned", @"7: not assigned", @"Admins"] objectAtIndex:enum]

@interface Model : NSObject

+(Model*)sharedInstance;
-(void)saveToDisk;
+(PHPhotoLibrary*)defaultAssetsLibrary;

@property (nonatomic, assign) BOOL isAppLanguageRTL;

@property (nonatomic, strong) NSString *serverProtocol;     // => Manages cases where the Piwigo server
@property (nonatomic, strong) NSString *serverName;         // returns the wrong protocol (http: or https:)
@property (nonatomic, strong) NSString *pwgToken;
@property (nonatomic, strong) NSString *language;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *HttpUsername;
@property (nonatomic, strong) NSString *uploadFileTypes;
@property (nonatomic, assign) BOOL hasAdminRights;
@property (nonatomic, assign) BOOL usesCommunityPluginV29;
@property (nonatomic, assign) BOOL hasUploadedImages;
@property (nonatomic, assign) BOOL hadOpenedSession;
@property (nonatomic, assign) BOOL performedHTTPauthentication;
@property (nonatomic, assign) BOOL userCancelledCommunication;
@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, assign) NSInteger maxConnectionsPerHost;

@property (nonatomic, assign) BOOL hasSquareSizeImages;
@property (nonatomic, assign) BOOL hasThumbSizeImages;
@property (nonatomic, assign) BOOL hasXXSmallSizeImages;
@property (nonatomic, assign) BOOL hasXSmallSizeImages;
@property (nonatomic, assign) BOOL hasSmallSizeImages;
@property (nonatomic, assign) BOOL hasMediumSizeImages;
@property (nonatomic, assign) BOOL hasLargeSizeImages;
@property (nonatomic, assign) BOOL hasXLargeSizeImages;
@property (nonatomic, assign) BOOL hasXXLargeSizeImages;
@property (nonatomic, assign) NSInteger defaultThumbnailSize;
@property (nonatomic, assign) NSInteger defaultImagePreviewSize;
@property (nonatomic, assign) BOOL displayImageTitles;
@property (nonatomic, assign) BOOL isDarkPaletteActive;
@property (nonatomic, assign) BOOL switchPaletteAutomatically;
@property (nonatomic, assign) NSInteger switchPaletteThreshold;
@property (nonatomic, assign) BOOL isDarkPaletteModeActive;
@property (nonatomic, assign) NSInteger thumbnailsPerRowInPortrait;

@property (nonatomic, assign) kPiwigoPrivacy defaultPrivacyLevel;
@property (nonatomic, strong) NSString *defaultAuthor;
@property (nonatomic, assign) BOOL stripGPSdataOnUpload;
@property (nonatomic, assign) BOOL resizeImageOnUpload;
@property (nonatomic, assign) NSInteger photoResize;
@property (nonatomic, assign) BOOL compressImageOnUpload;
@property (nonatomic, assign) NSInteger photoQuality;
@property (nonatomic, assign) BOOL deleteImageAfterUpload;

@property (nonatomic, assign) kPiwigoSortCategory defaultSort;
@property (nonatomic, assign) NSInteger imagesPerPage;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger lastPageImageCount;

@property (nonatomic, assign) BOOL loadAllCategoryInfo;
@property (nonatomic, assign) NSInteger memoryCache;
@property (nonatomic, assign) NSInteger diskCache;


-(NSString*)getNameForPrivacyLevel:(kPiwigoPrivacy)privacyLevel;

@end
