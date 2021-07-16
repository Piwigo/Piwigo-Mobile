//
//  Model.m
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import <Photos/Photos.h>

#import "Model.h"
#import "PiwigoImageData.h"
#import "ImagesCollection.h"


NSInteger const kPiwigoMemoryCacheInc = 8;      // Slider increment
NSInteger const kPiwigoMemoryCacheMin = 0;      // Minimum size
NSInteger const kPiwigoMemoryCacheMax = 256;    // Maximum size

NSInteger const kPiwigoDiskCacheInc   = 64;     // Slider increment
NSInteger const kPiwigoDiskCacheMin   = 128;    // Minimum size
NSInteger const kPiwigoDiskCacheMax   = 2048;   // Maximum size

CGFloat const kPiwigoPadSubViewWidth  = 375.0;  // Preferred popover view width on iPad
CGFloat const kPiwigoPadSettingsWidth = 512.0;  // Preferred Settings view width on iPad

NSTimeInterval const k1WeekInDays  = 60 * 60 * 24 *  7.0;
NSTimeInterval const k2WeeksInDays = 60 * 60 * 24 * 14.0;
NSTimeInterval const k3WeeksInDays = 60 * 60 * 24 * 21.0;

NSInteger const kDelayPiwigoHUD = 500;

@interface Model()

// Network variables
@property (nonatomic, strong) NSString *serverProtocol;
@property (nonatomic, strong) NSString *serverPath;
@property (nonatomic, assign) NSUInteger stringEncoding;
@property (nonatomic, strong) NSString *HttpUsername;
@property (nonatomic, strong) NSString *username;

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) AFHTTPSessionManager *imagesSessionManager;
@property (nonatomic, strong) NSURLCache *imageCache;
@property (nonatomic, strong) AFAutoPurgingImageCache *thumbnailCache;

@property (nonatomic, assign) BOOL usesCommunityPluginV29;
@property (nonatomic, assign) BOOL usesUploadAsync;
@property (nonatomic, assign) BOOL didFailHTTPauthentication;
@property (nonatomic, assign) BOOL didApproveCertificate;
@property (nonatomic, assign) BOOL didRejectCertificate;
@property (nonatomic, strong) NSString *certificateInformation;
@property (nonatomic, assign) BOOL userCancelledCommunication;
@property (nonatomic, assign) BOOL hasNormalRights;
@property (nonatomic, assign) BOOL hasAdminRights;
@property (nonatomic, assign) BOOL hadOpenedSession;
@property (nonatomic, strong) NSDate *dateOfLastLogin;
@property (nonatomic, strong) NSString *pwgToken;
@property (nonatomic, strong) NSString *language;
@property (nonatomic, strong) NSString *version;

// Album variables
@property (nonatomic, assign) NSInteger defaultCategory;
@property (nonatomic, assign) kPiwigoImageSize defaultAlbumThumbnailSize;
@property (nonatomic, strong) NSString *recentCategories;
@property (nonatomic, assign) NSInteger maxNberRecentCategories;
@property (nonatomic, assign) kPiwigoSortObjc defaultSort;
@property (nonatomic, assign) BOOL displayImageTitles;
@property (nonatomic, assign) kPiwigoImageSize defaultThumbnailSize;
@property (nonatomic, assign) NSInteger thumbnailsPerRowInPortrait;

// Available image sizes
@property (nonatomic, assign) BOOL hasSquareSizeImages;
@property (nonatomic, assign) BOOL hasThumbSizeImages;
@property (nonatomic, assign) BOOL hasXXSmallSizeImages;
@property (nonatomic, assign) BOOL hasXSmallSizeImages;
@property (nonatomic, assign) BOOL hasSmallSizeImages;
@property (nonatomic, assign) BOOL hasMediumSizeImages;
@property (nonatomic, assign) BOOL hasLargeSizeImages;
@property (nonatomic, assign) BOOL hasXLargeSizeImages;
@property (nonatomic, assign) BOOL hasXXLargeSizeImages;

// Image variables
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

// App variables - orientation, Core Data migration issue
@property (nonatomic, assign) BOOL isAppLanguageRTL;
@property (nonatomic, assign) BOOL couldNotMigrateCoreDataStore;
@property (nonatomic, assign) BOOL isDarkPaletteActive;
@property (nonatomic, assign) BOOL switchPaletteAutomatically;
@property (nonatomic, assign) NSInteger switchPaletteThreshold;
@property (nonatomic, assign) BOOL isDarkPaletteModeActive;
@property (nonatomic, assign) BOOL isLightPaletteModeActive;
@property (nonatomic, assign) BOOL isSystemDarkModeActive;
@property (nonatomic, assign) NSInteger memoryCache;
@property (nonatomic, assign) NSInteger diskCache;
@property (nonatomic, assign) UInt16 didWatchHelpViews;
@property (nonatomic, assign) NSTimeInterval dateOfLastTranslationRequest;
@property (nonatomic, assign) BOOL available;               // Unused, i.e. available flag

// Default image upload settings
@property (nonatomic, assign) kPiwigoSortObjc localImagesSort;
@property (nonatomic, strong) NSString *defaultAuthor;
@property (nonatomic, assign) kPiwigoPrivacyObjc defaultPrivacyLevel;
@property (nonatomic, assign) BOOL stripGPSdataOnUpload;
@property (nonatomic, assign) BOOL resizeImageOnUpload;
@property (nonatomic, assign) NSInteger photoResize;
@property (nonatomic, assign) BOOL compressImageOnUpload;
@property (nonatomic, assign) NSInteger photoQuality;
@property (nonatomic, assign) BOOL deleteImageAfterUpload;
@property (nonatomic, assign) BOOL prefixFileNameBeforeUpload;
@property (nonatomic, strong) NSString *defaultPrefix;
@property (nonatomic, strong) NSString *serverFileTypes;
@property (nonatomic, assign) NSInteger uploadChunkSize;
@property (nonatomic, assign) BOOL wifiOnlyUploading;
@property (nonatomic, assign) BOOL isAutoUploadActive;
@property (nonatomic, strong) NSString *autoUploadAlbumId;
@property (nonatomic, assign) NSInteger autoUploadCategoryId;
@property (nonatomic, strong) NSString *autoUploadTagIds;
@property (nonatomic, strong) NSString *autoUploadComments;

@end

@implementation Model

+ (Model*)sharedInstance
{
	static Model *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
        
        // Directionality of the language in the user interface of the app?
        UIUserInterfaceLayoutDirection direction = [UIApplication sharedApplication].userInterfaceLayoutDirection;
        instance.isAppLanguageRTL = (direction == UIUserInterfaceLayoutDirectionRightToLeft);
		
        instance.serverProtocol = @"https://";
        instance.serverPath = @"";
        instance.stringEncoding = NSUTF8StringEncoding; // UTF-8 by default
        instance.username = @"";
        instance.HttpUsername = @"";
        instance.usesCommunityPluginV29 = NO;           // Checked at each new session
        instance.usesUploadAsync = NO;

        instance.hasAdminRights = NO;
        instance.hasNormalRights = NO;
        instance.hadOpenedSession = NO;
        instance.dateOfLastLogin = [NSDate distantPast];
        instance.didRejectCertificate = NO;
        instance.didFailHTTPauthentication = NO;
        instance.didApproveCertificate = NO;
        instance.certificateInformation = @"";
        instance.userCancelledCommunication = NO;

        // Album/category settings
        instance.defaultCategory = 0;                   // Root album by default
        instance.defaultAlbumThumbnailSize = [PiwigoImageData optimumAlbumThumbnailSizeForDevice];
        instance.recentCategories = @"0";
        instance.maxNberRecentCategories = 5;

        // Sort images by date: old to new
		instance.defaultSort = kPiwigoSortObjcDateCreatedAscending;
        
        // Display images titles in collection views
        instance.displayImageTitles = YES;
		
        // Default available Piwigo sizes
        instance.hasSquareSizeImages = YES;
        instance.hasThumbSizeImages = YES;
        instance.hasXXSmallSizeImages = NO;
        instance.hasXSmallSizeImages = NO;
        instance.hasSmallSizeImages = NO;
        instance.hasMediumSizeImages = YES;
        instance.hasLargeSizeImages = NO;
        instance.hasXLargeSizeImages = NO;
        instance.hasXXLargeSizeImages = NO;
        
        // Optimised image thumbnail size, will be cross-checked at login
        instance.defaultThumbnailSize = [PiwigoImageData optimumImageThumbnailSizeForDevice];
        instance.thumbnailsPerRowInPortrait = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? 4 : 6;

        // Default image settings
		instance.defaultImagePreviewSize = [PiwigoImageData optimumImageSizeForDevice];
        instance.shareMetadataTypeAirDrop = YES;
        instance.shareMetadataTypeAssignToContact = NO;
        instance.shareMetadataTypeCopyToPasteboard = NO;
        instance.shareMetadataTypeMail = YES;
        instance.shareMetadataTypeMessage = YES;
        instance.shareMetadataTypePostToFacebook = NO;
        instance.shareMetadataTypeMessenger = NO;
        instance.shareMetadataTypePostToFlickr = YES;
        instance.shareMetadataTypePostInstagram = NO;
        instance.shareMetadataTypePostToSignal = YES;
        instance.shareMetadataTypePostToSnapchat = NO;
        instance.shareMetadataTypePostToTencentWeibo = NO;
        instance.shareMetadataTypePostToTwitter = NO;
        instance.shareMetadataTypePostToVimeo = NO;
        instance.shareMetadataTypePostToWeibo = NO;
        instance.shareMetadataTypePostToWhatsApp = NO;
        instance.shareMetadataTypeSaveToCameraRoll = YES;
        instance.shareMetadataTypeOther = NO;
        
        // Default image upload settings
        instance.uploadChunkSize = 500;             // 500 KB chunk size
        instance.defaultAuthor = @"";
        instance.defaultPrivacyLevel = kPiwigoPrivacyObjcEverybody;
        instance.stripGPSdataOnUpload = NO;         // Upload images with private metadata
        instance.photoQuality = 95;                 // 95% image quality at compression
        instance.photoResize = 100;                 // Do not resize images
        instance.deleteImageAfterUpload = NO;
        instance.prefixFileNameBeforeUpload = NO;
        instance.defaultPrefix = @"";
        instance.localImagesSort = kPiwigoSortObjcDateCreatedDescending;    // i.e. new to old
        instance.wifiOnlyUploading = NO;            // Wi-Fi only option
        instance.isAutoUploadActive = NO;           // Auto-upload On/Off
        instance.autoUploadAlbumId = @"";           // Unknown source Photos album
        instance.autoUploadCategoryId = NSNotFound; // Unknown destination Piwigo album
        instance.autoUploadTagIds = @"";            // No tag
        instance.autoUploadComments = @"";          // No comment

        // Default palette mode
        instance.isDarkPaletteActive = NO;
        instance.switchPaletteAutomatically = YES;
        instance.switchPaletteThreshold = 40;
        instance.isLightPaletteModeActive = NO;
        instance.isDarkPaletteModeActive = NO;
        instance.isSystemDarkModeActive = NO;
        
        // Default cache settings
        instance.couldNotMigrateCoreDataStore = NO;
        instance.available = YES;                           // Available…
		instance.diskCache = kPiwigoDiskCacheMin * 4;       // i.e. 512 MB
		instance.memoryCache = kPiwigoMemoryCacheInc * 2;   // i.e. 16 MB
		
        // Remember which help views were watched
        instance.didWatchHelpViews = 0b0000000000000000;
        
        // Request help for translating Piwigo every 2 weeks or so
        instance.dateOfLastTranslationRequest = [[NSDate date] timeIntervalSinceReferenceDate] - k2WeeksInDays;
	});
	return instance;
}

-(NSString *)getNameForPrivacyLevel:(kPiwigoPrivacyObjc)privacyLevel
{
	NSString *name = @"";
	switch(privacyLevel)
	{
		case kPiwigoPrivacyObjcAdmins:
			name = NSLocalizedString(@"privacyLevel_admin", @"Admins");
			break;
		case kPiwigoPrivacyObjcAdminsFamily:
			name = NSLocalizedString(@"privacyLevel_adminFamily", @"Admins, Family");
			break;
		case kPiwigoPrivacyObjcAdminsFamilyFriends:
			name = NSLocalizedString(@"privacyLevel_adminsFamilyFriends", @"Admins, Family, Friends");
			break;
		case kPiwigoPrivacyObjcAdminsFamilyFriendsContacts:
			name = NSLocalizedString(@"privacyLevel_adminsFamilyFriendsContacts", @"Admins, Family, Friends, Contacts");
			break;
		case kPiwigoPrivacyObjcEverybody:
			name = NSLocalizedString(@"privacyLevel_everybody", @"Everybody");
			break;
        default:
			break;
	}
	
	return name;
}


-(NSInteger)photoQuality {
    if (_photoQuality < 50) {
        _photoQuality = 50;
    } else if (_photoQuality > 98) {
        _photoQuality = 98;
    }
    return _photoQuality;
}


#pragma mark - Saving to Disk
+ (NSString *)applicationDocumentsDirectory
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	return [basePath stringByAppendingPathComponent:@"data"];
}

- (void)readFromDisk
{
	NSString *dataPath = [Model applicationDocumentsDirectory];
	NSData *codedData = [[NSData alloc] initWithContentsOfFile:dataPath];
	if (codedData)
	{
		NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
		Model *modelData = [unarchiver decodeObjectForKey:@"Model"];
        
        // => Network variables stored in UserDefaults / App Group
        NetworkVarsObjc.serverProtocol = modelData.serverProtocol;
        NetworkVarsObjc.serverPath = modelData.serverPath;
        NetworkVarsObjc.stringEncoding = modelData.stringEncoding;
        NetworkVarsObjc.httpUsername = modelData.HttpUsername;
        NetworkVarsObjc.username = modelData.username;

        // Data cache variables stored in UserDefaults / App Group
        CacheVarsObjc.couldNotMigrateCoreDataStore = modelData.couldNotMigrateCoreDataStore;

        // Album variables stored in UserDefaults / Standard
        AlbumVars.defaultCategory = modelData.defaultCategory;
        AlbumVars.defaultAlbumThumbnailSize = modelData.defaultAlbumThumbnailSize;
        AlbumVars.recentCategories = modelData.recentCategories;
        AlbumVars.maxNberRecentCategories = modelData.maxNberRecentCategories;
        AlbumVars.defaultSort = modelData.defaultSort;
        AlbumVars.displayImageTitles = modelData.displayImageTitles;
        AlbumVars.defaultThumbnailSize = modelData.defaultThumbnailSize;
        AlbumVars.thumbnailsPerRowInPortrait = modelData.thumbnailsPerRowInPortrait;

        ImageVars.shared.defaultImagePreviewSize = modelData.defaultImagePreviewSize;
        ImageVars.shared.shareMetadataTypeAirDrop = modelData.shareMetadataTypeAirDrop;
        ImageVars.shared.shareMetadataTypeAssignToContact = modelData.shareMetadataTypeAssignToContact;
        ImageVars.shared.shareMetadataTypeCopyToPasteboard = modelData.shareMetadataTypeCopyToPasteboard;
        ImageVars.shared.shareMetadataTypeMail = modelData.shareMetadataTypeMail;
        ImageVars.shared.shareMetadataTypeMessage = modelData.shareMetadataTypeMessage;
        ImageVars.shared.shareMetadataTypePostToFacebook = modelData.shareMetadataTypePostToFacebook;
        ImageVars.shared.shareMetadataTypeMessenger = modelData.shareMetadataTypeMessenger;
        ImageVars.shared.shareMetadataTypePostToFlickr = modelData.shareMetadataTypePostToFlickr;
        ImageVars.shared.shareMetadataTypePostInstagram = modelData.shareMetadataTypePostInstagram;
        ImageVars.shared.shareMetadataTypePostToSignal = modelData.shareMetadataTypePostToSignal;
        ImageVars.shared.shareMetadataTypePostToSnapchat = modelData.shareMetadataTypePostToSnapchat;
        ImageVars.shared.shareMetadataTypePostToTencentWeibo = modelData.shareMetadataTypePostToTencentWeibo;
        ImageVars.shared.shareMetadataTypePostToTwitter = modelData.shareMetadataTypePostToTwitter;
        ImageVars.shared.shareMetadataTypePostToVimeo = modelData.shareMetadataTypePostToVimeo;
        ImageVars.shared.shareMetadataTypePostToWeibo = modelData.shareMetadataTypePostToWeibo;
        ImageVars.shared.shareMetadataTypePostToWhatsApp = modelData.shareMetadataTypePostToWhatsApp;
        ImageVars.shared.shareMetadataTypeSaveToCameraRoll = modelData.shareMetadataTypeSaveToCameraRoll;
        ImageVars.shared.shareMetadataTypeOther = modelData.shareMetadataTypeOther;

        AppVars.isDarkPaletteActive = modelData.isDarkPaletteActive;
        AppVars.switchPaletteAutomatically = modelData.switchPaletteAutomatically;
        AppVars.switchPaletteThreshold = modelData.switchPaletteThreshold;
        AppVars.isDarkPaletteModeActive = modelData.isDarkPaletteModeActive;
        AppVars.isLightPaletteModeActive = modelData.isLightPaletteModeActive;
        AppVars.diskCache = modelData.diskCache;
        AppVars.memoryCache = modelData.memoryCache;
        AppVars.didWatchHelpViews = modelData.didWatchHelpViews;
        AppVars.dateOfLastTranslationRequest = modelData.dateOfLastTranslationRequest;

        UploadVarsObjc.defaultPrivacyLevel = modelData.defaultPrivacyLevel;
        UploadVarsObjc.defaultAuthor = modelData.defaultAuthor;
        UploadVarsObjc.photoQuality = modelData.photoQuality;
        NSInteger size = [UIScreen mainScreen].nativeBounds.size.height * modelData.photoResize;
        UploadVarsObjc.photoMaxSize = [UploadVarsObjc selectedPhotoSizeFromSize:size];
        UploadVarsObjc.videoMaxSize = [UploadVarsObjc selectedVideoSizeFromSize:size];
        UploadVarsObjc.resizeImageOnUpload = modelData.resizeImageOnUpload;
        UploadVarsObjc.stripGPSdataOnUpload = modelData.stripGPSdataOnUpload;
        UploadVarsObjc.compressImageOnUpload = modelData.compressImageOnUpload;
        UploadVarsObjc.deleteImageAfterUpload = modelData.deleteImageAfterUpload;
        UploadVarsObjc.uploadChunkSize = modelData.uploadChunkSize;
        UploadVarsObjc.prefixFileNameBeforeUpload = modelData.prefixFileNameBeforeUpload;
        UploadVarsObjc.defaultPrefix = modelData.defaultPrefix;
        UploadVarsObjc.localImagesSort = modelData.localImagesSort;
        UploadVarsObjc.wifiOnlyUploading = modelData.wifiOnlyUploading;
        UploadVarsObjc.isAutoUploadActive = modelData.isAutoUploadActive;
        UploadVarsObjc.autoUploadAlbumId = modelData.autoUploadAlbumId;
        UploadVarsObjc.autoUploadCategoryId = modelData.autoUploadCategoryId;
        UploadVarsObjc.autoUploadTagIds = modelData.autoUploadTagIds;
        UploadVarsObjc.autoUploadComments = modelData.autoUploadComments;
        
        // Delete file which is replaced by UserDefaults default and App Groups
        [NSFileManager.defaultManager removeItemAtPath:dataPath error:nil];
	}
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	NSArray *savedData = [decoder decodeObjectForKey:@"Model"];
    
    NSString *serverPath = [savedData objectAtIndex:0];
    if ([serverPath isEqualToString:@"(null)(null)"]) {
        self.serverPath = @"";
    } else {
        self.serverPath = serverPath;
    }
	self.defaultPrivacyLevel = (kPiwigoPrivacyObjc)[[savedData objectAtIndex:1] integerValue];
	self.defaultAuthor = [savedData objectAtIndex:2];

    self.diskCache = MAX([[savedData objectAtIndex:3] integerValue], kPiwigoDiskCacheMin * 4);      // i.e. > 512 MB
    self.diskCache = MIN(self.diskCache, kPiwigoDiskCacheMax);                                      // i.e. < 2 GB
	self.memoryCache = MAX([[savedData objectAtIndex:4] integerValue], kPiwigoMemoryCacheInc * 2);  // i.e. > 16 MB
    self.memoryCache = MIN(self.memoryCache, kPiwigoMemoryCacheMax);                                // i.e. < 256 MB

    self.photoQuality = [[savedData objectAtIndex:5] integerValue];
	self.photoResize = [[savedData objectAtIndex:6] integerValue];
	if(savedData.count > 7)
	{
		self.serverProtocol = [savedData objectAtIndex:7];
	} else {
		self.serverProtocol = @"https://";
	}
	if(savedData.count > 8)
	{
		self.available = [[savedData objectAtIndex:8] boolValue];
	} else {
		self.available = YES;
	}
	if(savedData.count > 9) {
		self.defaultSort = (kPiwigoSortObjc)[[savedData objectAtIndex:9] intValue];
	} else {
		self.defaultSort = kPiwigoSortObjcDateCreatedAscending;
	}
	if(savedData.count > 10) {
		self.resizeImageOnUpload = [[savedData objectAtIndex:10] boolValue];
	} else {
		self.resizeImageOnUpload = NO;
        self.photoResize = 100;
	}
    if(savedData.count > 11) {
        if(savedData.count > 47) {
            self.defaultImagePreviewSize = (kPiwigoImageSize)[[savedData objectAtIndex:11] integerValue];
        } else {
            // Just updated to 2.4.2…
            self.defaultImagePreviewSize = [PiwigoImageData optimumImageSizeForDevice];
        }
	} else {
		self.defaultImagePreviewSize = [PiwigoImageData optimumImageSizeForDevice];
	}
	if(savedData.count > 12) {
		self.stripGPSdataOnUpload = [[savedData objectAtIndex:12] boolValue];
	} else {
		self.stripGPSdataOnUpload = NO;
	}
    if(savedData.count > 13) {
        if(savedData.count > 47) {
            self.defaultThumbnailSize = (kPiwigoImageSize)[[savedData objectAtIndex:13] integerValue];
        } else {
            // Just updated to 2.4.2…
            self.defaultThumbnailSize = [PiwigoImageData optimumImageThumbnailSizeForDevice];
        }
	} else {
		self.defaultThumbnailSize = [PiwigoImageData optimumImageThumbnailSizeForDevice];
	}
	if(savedData.count > 14) {
		self.displayImageTitles = [[savedData objectAtIndex:14] boolValue];
	} else {
		self.displayImageTitles = YES;
	}
    if(savedData.count > 15) {
        self.compressImageOnUpload = [[savedData objectAtIndex:15] boolValue];
    } else {
        // Previously, there was one slider for both resize & compress options
        // because resize and JPEG compression was always performed before uploading
        if (self.resizeImageOnUpload) {     // Option was active, but for doing what?
            if (self.photoResize < 100) {
                self.resizeImageOnUpload = YES;
            } else {
                self.resizeImageOnUpload = NO;
                self.photoResize = 100;
            }
            if (self.photoQuality < 100) {
                self.compressImageOnUpload = YES;
            } else {
                self.compressImageOnUpload = NO;
                self.photoQuality = 98;
            }
        } else {
            self.compressImageOnUpload = NO;
            self.photoResize = 100;
            self.photoQuality = 98;
        }
    }
    if(savedData.count > 16) {
        self.deleteImageAfterUpload = [[savedData objectAtIndex:16] boolValue];
    } else {
        self.deleteImageAfterUpload = NO;
    }
    if (savedData.count > 17) {
        self.username = [savedData objectAtIndex:17];
    } else {
        self.username = @"";
    }
    if (savedData.count > 18) {
        self.HttpUsername = [savedData objectAtIndex:18];
    } else {
        self.HttpUsername = @"";
    }
    if(savedData.count > 19) {
        self.isDarkPaletteActive = [[savedData objectAtIndex:19] boolValue];
    } else {
        self.isDarkPaletteActive = NO;
    }
    if(savedData.count > 20) {
        self.switchPaletteAutomatically = [[savedData objectAtIndex:20] boolValue];
    } else {
        self.switchPaletteAutomatically = YES;
    }
    if(savedData.count > 21) {
        self.switchPaletteThreshold = [[savedData objectAtIndex:21] integerValue];
    } else {
        self.switchPaletteThreshold = 40;
    }
    if(savedData.count > 22) {
        self.isDarkPaletteModeActive = [[savedData objectAtIndex:22] boolValue];
    } else {
        self.isDarkPaletteModeActive = NO;
    }
    NSInteger nberOfImages = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? 4 : 6;
    if(savedData.count > 23) {
        if(savedData.count > 47) {
            self.thumbnailsPerRowInPortrait = [[savedData objectAtIndex:23] integerValue];
        } else {
            NSInteger minNberOfImages = [ImagesCollection minNberOfImagesPerRow];
            self.thumbnailsPerRowInPortrait = MAX(minNberOfImages, [[savedData objectAtIndex:23] integerValue]);
        }
    } else {
        // Default values (will be cross-checked at login)
        NSInteger minNberOfImages = [ImagesCollection minNberOfImagesPerRow];
        self.thumbnailsPerRowInPortrait = MAX(minNberOfImages, nberOfImages);
    }
    // Chek that default number fits inside selected range
    self.thumbnailsPerRowInPortrait = MAX(self.thumbnailsPerRowInPortrait, nberOfImages);
    self.thumbnailsPerRowInPortrait = MIN(self.thumbnailsPerRowInPortrait, 2*nberOfImages);
    if(savedData.count > 24) {
        self.defaultCategory = [[savedData objectAtIndex:24] integerValue];
    } else {
        self.defaultCategory = 0;
    }
    if(savedData.count > 25) {
        self.dateOfLastTranslationRequest = [[savedData objectAtIndex:25] doubleValue];
    } else {
        self.dateOfLastTranslationRequest = [[NSDate date] timeIntervalSinceReferenceDate] - k2WeeksInDays;
    }
    if(savedData.count > 26) {
        self.couldNotMigrateCoreDataStore = [[savedData objectAtIndex:26] boolValue];
    } else {
        self.couldNotMigrateCoreDataStore = NO;
    }
    if(savedData.count > 27) {
        self.shareMetadataTypeAirDrop = [[savedData objectAtIndex:27] boolValue];
    } else {
        self.shareMetadataTypeAirDrop = YES;
    }
    if(savedData.count > 28) {
        self.shareMetadataTypeAssignToContact = [[savedData objectAtIndex:28] boolValue];
    } else {
        self.shareMetadataTypeAssignToContact = NO;
    }
    if(savedData.count > 29) {
        self.shareMetadataTypeCopyToPasteboard = [[savedData objectAtIndex:29] boolValue];
    } else {
        self.shareMetadataTypeCopyToPasteboard = NO;
    }
    if(savedData.count > 30) {
        self.shareMetadataTypeMail = [[savedData objectAtIndex:30] boolValue];
    } else {
        self.shareMetadataTypeMail = YES;
    }
    if(savedData.count > 31) {
        self.shareMetadataTypeMessage = [[savedData objectAtIndex:31] boolValue];
    } else {
        self.shareMetadataTypeMessage = YES;
    }
    if(savedData.count > 32) {
        self.shareMetadataTypePostToFacebook = [[savedData objectAtIndex:32] boolValue];
    } else {
        self.shareMetadataTypePostToFacebook = NO;
    }
    if(savedData.count > 33) {
        self.shareMetadataTypeMessenger = [[savedData objectAtIndex:33] boolValue];
    } else {
        self.shareMetadataTypeMessenger = NO;
    }
    if(savedData.count > 34) {
        self.shareMetadataTypePostToFlickr = [[savedData objectAtIndex:34] boolValue];
    } else {
        self.shareMetadataTypePostToFlickr = YES;
    }
    if(savedData.count > 35) {
        self.shareMetadataTypePostInstagram = [[savedData objectAtIndex:35] boolValue];
    } else {
        self.shareMetadataTypePostInstagram = NO;
    }
    if(savedData.count > 36) {
        self.shareMetadataTypePostToSignal = [[savedData objectAtIndex:36] boolValue];
    } else {
        self.shareMetadataTypePostToSignal = YES;
    }
    if(savedData.count > 37) {
        self.shareMetadataTypePostToSnapchat = [[savedData objectAtIndex:37] boolValue];
    } else {
        self.shareMetadataTypePostToSnapchat = NO;
    }
    if(savedData.count > 38) {
        self.shareMetadataTypePostToTencentWeibo = [[savedData objectAtIndex:38] boolValue];
    } else {
        self.shareMetadataTypePostToTencentWeibo = NO;
    }
    if(savedData.count > 39) {
        self.shareMetadataTypePostToTwitter = [[savedData objectAtIndex:39] boolValue];
    } else {
        self.shareMetadataTypePostToTwitter = NO;
    }
    if(savedData.count > 40) {
        self.shareMetadataTypePostToVimeo = [[savedData objectAtIndex:40] boolValue];
    } else {
        self.shareMetadataTypePostToVimeo = NO;
    }
    if(savedData.count > 41) {
        self.shareMetadataTypePostToWeibo = [[savedData objectAtIndex:41] boolValue];
    } else {
        self.shareMetadataTypePostToWeibo = NO;
    }
    if(savedData.count > 42) {
        self.shareMetadataTypePostToWhatsApp = [[savedData objectAtIndex:42] boolValue];
    } else {
        self.shareMetadataTypePostToWhatsApp = NO;
    }
    if(savedData.count > 43) {
        self.shareMetadataTypeSaveToCameraRoll = [[savedData objectAtIndex:43] boolValue];
    } else {
        self.shareMetadataTypeSaveToCameraRoll = YES;
    }
    if(savedData.count > 44) {
        self.shareMetadataTypeOther = [[savedData objectAtIndex:44] boolValue];
    } else {
        self.shareMetadataTypeOther = NO;
    }
    if(savedData.count > 45) {
        self.uploadChunkSize = [[savedData objectAtIndex:45] integerValue];
    } else {
        self.uploadChunkSize = 500;
    }
    if(savedData.count > 46) {
        self.stringEncoding = [[savedData objectAtIndex:46] unsignedIntegerValue];
    } else {
        self.stringEncoding = NSUTF8StringEncoding;
    }
    if(savedData.count > 47) {
        self.defaultAlbumThumbnailSize = (kPiwigoImageSize)[[savedData objectAtIndex:47] integerValue];
    } else {
        self.defaultAlbumThumbnailSize = [PiwigoImageData optimumAlbumThumbnailSizeForDevice];
    }
    if(savedData.count > 48) {
        self.recentCategories = [savedData objectAtIndex:48];
    } else {
        self.recentCategories = @"0";               // i.e. root album
    }
    if(savedData.count > 49) {
        self.maxNberRecentCategories = [[savedData objectAtIndex:49] unsignedIntegerValue];
    } else {
        self.maxNberRecentCategories = 5;           // Default value
    }
    if(savedData.count > 50) {
        self.prefixFileNameBeforeUpload = [[savedData objectAtIndex:50] boolValue];
    } else {
        self.prefixFileNameBeforeUpload = NO;       // Default value
    }
    if(savedData.count > 51) {
        self.defaultPrefix = [savedData objectAtIndex:51];
    } else {
        self.defaultPrefix = @"";       // No prefix to filenames by default value
    }
    if(savedData.count > 52) {
        self.localImagesSort = (kPiwigoSortObjc)[[savedData objectAtIndex:52] intValue];
    } else {
        self.localImagesSort = kPiwigoSortObjcDateCreatedDescending;
    }
    if(savedData.count > 53) {
        self.wifiOnlyUploading = [[savedData objectAtIndex:53] boolValue];
    } else {
        self.wifiOnlyUploading = NO;    // Wi-Fi not required for uploading
    }
    if(savedData.count > 54) {
        self.didWatchHelpViews = [[savedData objectAtIndex:54] integerValue];
//        self.didWatchHelpViews = 0; // for debugging
    } else {
        self.didWatchHelpViews = 0;
    }
    if(savedData.count > 55) {
        self.isLightPaletteModeActive = [[savedData objectAtIndex:55] boolValue];
    } else {
        self.isLightPaletteModeActive = NO;
    }
    if(savedData.count > 56) {
        self.isAutoUploadActive = [[savedData objectAtIndex:56] boolValue];
    } else {
        self.isAutoUploadActive = NO;
    }
    if(savedData.count > 57) {
        self.autoUploadAlbumId = [savedData objectAtIndex:57];
    } else {
        self.autoUploadAlbumId = @"";
    }
    if(savedData.count > 58) {
        self.autoUploadCategoryId = [[savedData objectAtIndex:58] integerValue];
    } else {
        self.autoUploadCategoryId = NSNotFound;
    }
    if(savedData.count > 59) {
        self.autoUploadTagIds = [savedData objectAtIndex:59];
    } else {
        self.autoUploadTagIds = @"";
    }
    if(savedData.count > 60) {
        self.autoUploadComments = [savedData objectAtIndex:60];
    } else {
        self.autoUploadComments = @"";
    }
	return self;
}

@end
