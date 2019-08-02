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
#import "CategorySortViewController.h"

FOUNDATION_EXPORT NSInteger const kPiwigoMinMemoryCache;
FOUNDATION_EXPORT NSInteger const kPiwigoMinDiskCache;
FOUNDATION_EXPORT NSInteger const kPiwigoMaxMemoryCache;
FOUNDATION_EXPORT NSInteger const kPiwigoMaxDiskCache;

FOUNDATION_EXPORT NSTimeInterval const k1WeekInDays;
FOUNDATION_EXPORT NSTimeInterval const k2WeeksInDays;
FOUNDATION_EXPORT NSTimeInterval const k3WeeksInDays;

FOUNDATION_EXPORT NSString *kPiwigoActivityTypeMessenger;
FOUNDATION_EXPORT NSString *kPiwigoActivityTypePostInstagram;
FOUNDATION_EXPORT NSString *kPiwigoActivityTypePostToSignal;
FOUNDATION_EXPORT NSString *kPiwigoActivityTypePostToSnapchat;
FOUNDATION_EXPORT NSString *kPiwigoActivityTypePostToWhatsApp;
FOUNDATION_EXPORT NSString *kPiwigoActivityTypeOther;

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
@property (nonatomic, strong) AFAutoPurgingImageCache *imageCache;
@property (nonatomic, strong) AFHTTPSessionManager *imagesSessionManager;
@property (nonatomic, strong) AFImageDownloader *imageDownloader;
@property (nonatomic, strong) AFHTTPSessionManager *imageUploadManager;

// Album/category settings
@property (nonatomic, assign) NSInteger defaultCategory;

// Sort images by date: old to new
@property (nonatomic, assign) kPiwigoSortCategory defaultSort;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger lastPageImageCount;

// Display images titles in collection views
@property (nonatomic, assign) BOOL displayImageTitles;

// Default available Piwigo sizes
@property (nonatomic, assign) BOOL hasSquareSizeImages;
@property (nonatomic, assign) BOOL hasThumbSizeImages;
@property (nonatomic, assign) BOOL hasXXSmallSizeImages;
@property (nonatomic, assign) BOOL hasXSmallSizeImages;
@property (nonatomic, assign) BOOL hasSmallSizeImages;
@property (nonatomic, assign) BOOL hasMediumSizeImages;
@property (nonatomic, assign) BOOL hasLargeSizeImages;
@property (nonatomic, assign) BOOL hasXLargeSizeImages;
@property (nonatomic, assign) BOOL hasXXLargeSizeImages;

// Default thumbnail size and number per row in portrait mode
@property (nonatomic, assign) NSInteger defaultThumbnailSize;
@property (nonatomic, assign) NSInteger thumbnailsPerRowInPortrait;

// Default image settings
@property (nonatomic, assign) BOOL didOptimiseImagePreviewSize;
@property (nonatomic, assign) NSInteger defaultImagePreviewSize;
@property (nonatomic, assign) BOOL shareMetadataTypeAirDrop;
@property (nonatomic, assign) BOOL shareMetadataTypeAssignToContact;
@property (nonatomic, assign) BOOL shareMetadataTypeCopyToPasteboard;
@property (nonatomic, assign) BOOL shareMetadataTypeMail;
@property (nonatomic, assign) BOOL shareMetadataTypeMessage;
@property (nonatomic, assign) BOOL shareMetadataTypePostToFacebook;
@property (nonatomic, assign) BOOL shareMetadataTypeMessenger;
@property (nonatomic, assign) BOOL shareMetadataTypePostToFlickr;
@property (nonatomic, assign) BOOL shareMetadataTypePostInstagram;
@property (nonatomic, assign) BOOL shareMetadataTypePostToSignal;
@property (nonatomic, assign) BOOL shareMetadataTypePostToSnapchat;
@property (nonatomic, assign) BOOL shareMetadataTypePostToTencentWeibo;
@property (nonatomic, assign) BOOL shareMetadataTypePostToTwitter;
@property (nonatomic, assign) BOOL shareMetadataTypePostToVimeo;
@property (nonatomic, assign) BOOL shareMetadataTypePostToWeibo;
@property (nonatomic, assign) BOOL shareMetadataTypePostToWhatsApp;
@property (nonatomic, assign) BOOL shareMetadataTypeSaveToCameraRoll;
@property (nonatomic, assign) BOOL shareMetadataTypeOther;

// Default image upload settings
@property (nonatomic, assign) NSInteger uploadChunkSize;
@property (nonatomic, strong) NSString *defaultAuthor;
@property (nonatomic, assign) kPiwigoPrivacy defaultPrivacyLevel;
@property (nonatomic, assign) BOOL stripGPSdataOnUpload;
@property (nonatomic, assign) BOOL resizeImageOnUpload;
@property (nonatomic, assign) NSInteger photoResize;
@property (nonatomic, assign) BOOL compressImageOnUpload;
@property (nonatomic, assign) NSInteger photoQuality;
@property (nonatomic, assign) BOOL deleteImageAfterUpload;

// Default palette mode
@property (nonatomic, assign) BOOL isDarkPaletteActive;
@property (nonatomic, assign) BOOL switchPaletteAutomatically;
@property (nonatomic, assign) NSInteger switchPaletteThreshold;
@property (nonatomic, assign) BOOL isDarkPaletteModeActive;

// Default cache settings
@property (nonatomic, assign) BOOL loadAllCategoryInfo;
@property (nonatomic, assign) NSInteger memoryCache;
@property (nonatomic, assign) NSInteger diskCache;

// Request help for translating Piwigo every month or so
@property (nonatomic, assign) NSTimeInterval dateOfLastTranslationRequest;

-(NSString *)getNameForPrivacyLevel:(kPiwigoPrivacy)privacyLevel;
-(NSString *)getNameForShareActivity:(NSString *)activity forWidth:(CGFloat)width;

@end
