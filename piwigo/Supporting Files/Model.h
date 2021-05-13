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

FOUNDATION_EXPORT NSInteger const kPiwigoMemoryCacheInc;
FOUNDATION_EXPORT NSInteger const kPiwigoMemoryCacheMin;
FOUNDATION_EXPORT NSInteger const kPiwigoMemoryCacheMax;

FOUNDATION_EXPORT NSInteger const kPiwigoDiskCacheInc;
FOUNDATION_EXPORT NSInteger const kPiwigoDiskCacheMin;
FOUNDATION_EXPORT NSInteger const kPiwigoDiskCacheMax;

FOUNDATION_EXPORT CGFloat const kPiwigoPadSubViewWidth;
FOUNDATION_EXPORT CGFloat const kPiwigoPadSettingsWidth;

FOUNDATION_EXPORT NSTimeInterval const k1WeekInDays;
FOUNDATION_EXPORT NSTimeInterval const k2WeeksInDays;
FOUNDATION_EXPORT NSTimeInterval const k3WeeksInDays;

FOUNDATION_EXPORT NSInteger const kDelayPiwigoHUD;

@class PHPhotoLibrary;

typedef enum {
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
-(void)saveToDisk;

@property (nonatomic, assign) BOOL isAppLanguageRTL;

@property (nonatomic, strong) NSString *serverProtocol;     // => Manages cases where the Piwigo server
@property (nonatomic, strong) NSString *serverPath;         // returns the wrong protocol (http: or https:)
@property (nonatomic, strong) NSString *pwgToken;
@property (nonatomic, strong) NSString *language;
@property (nonatomic, assign) NSUInteger stringEncoding;    // Character encoding used by the Piwigo server
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *HttpUsername;
@property (nonatomic, strong) NSString *serverFileTypes;    // File formats accepted by the Piwigo server
@property (nonatomic, assign) BOOL usesCommunityPluginV29;
@property (nonatomic, assign) BOOL usesUploadAsync;

@property (nonatomic, assign) BOOL hasAdminRights;
@property (nonatomic, assign) BOOL hasNormalRights;
@property (nonatomic, assign) BOOL hadOpenedSession;
@property (nonatomic, strong) NSDate *dateOfLastLogin;
@property (nonatomic, assign) BOOL didRejectCertificate;
@property (nonatomic, assign) BOOL didFailHTTPauthentication;
@property (nonatomic, assign) BOOL didApproveCertificate;
@property (nonatomic, strong) NSString *certificateInformation;
@property (nonatomic, assign) BOOL userCancelledCommunication;
@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) AFHTTPSessionManager *imagesSessionManager;
@property (nonatomic, strong) NSURLCache *imageCache;
@property (nonatomic, strong) AFAutoPurgingImageCache *thumbnailCache;

// Album/category settings
@property (nonatomic, assign) NSInteger defaultCategory;
@property (nonatomic, assign) kPiwigoImageSize defaultAlbumThumbnailSize;
@property (nonatomic, strong) NSString *recentCategories;
@property (nonatomic, assign) NSUInteger maxNberRecentCategories;

// Sort images by date: old to new
@property (nonatomic, assign) kPiwigoSort defaultSort;
@property (nonatomic, assign) NSInteger currentPage;

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
@property (nonatomic, assign) kPiwigoImageSize defaultThumbnailSize;
@property (nonatomic, assign) NSInteger thumbnailsPerRowInPortrait;

// Default image settings
@property (nonatomic, assign) kPiwigoImageSize defaultImagePreviewSize;
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
@property (nonatomic, assign) BOOL prefixFileNameBeforeUpload;
@property (nonatomic, strong) NSString *defaultPrefix;
@property (nonatomic, assign) kPiwigoSort localImagesSort;
@property (nonatomic, assign) BOOL wifiOnlyUploading;
@property (nonatomic, assign) BOOL isAutoUploadActive;
@property (nonatomic, strong) NSString *autoUploadAlbumId;
@property (nonatomic, assign) NSInteger autoUploadCategoryId;
@property (nonatomic, strong) NSString *autoUploadTagIds;

// Default color palette (adopts light/dark modes as from iOS 13)
@property (nonatomic, assign) BOOL isDarkPaletteActive;
@property (nonatomic, assign) BOOL switchPaletteAutomatically;
@property (nonatomic, assign) NSInteger switchPaletteThreshold;
@property (nonatomic, assign) BOOL isDarkPaletteModeActive;
@property (nonatomic, assign) BOOL isLightPaletteModeActive;
@property (nonatomic, assign) BOOL isSystemDarkModeActive;

// Default cache settings
@property (nonatomic, assign) BOOL available;
@property (nonatomic, assign) NSInteger memoryCache;
@property (nonatomic, assign) NSInteger diskCache;
@property (nonatomic, assign) BOOL couldNotMigrateCoreDataStore;

// Remember which help views were watched
@property (nonatomic, assign) UInt16 didWatchHelpViews;

// Request help for translating Piwigo every month or so
@property (nonatomic, assign) NSTimeInterval dateOfLastTranslationRequest;

-(NSString *)getNameForPrivacyLevel:(kPiwigoPrivacy)privacyLevel;

@end
