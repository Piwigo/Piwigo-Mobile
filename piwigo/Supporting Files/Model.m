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

NSTimeInterval const k1WeekInDays  = 60 * 60 * 24 *  7.0;
NSTimeInterval const k2WeeksInDays = 60 * 60 * 24 * 14.0;
NSTimeInterval const k3WeeksInDays = 60 * 60 * 24 * 21.0;

@interface Model()

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
		instance.defaultSort = kPiwigoSortDateCreatedAscending;
        
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
        instance.couldNotMigrateCoreDataStore = NO;
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
        instance.defaultPrivacyLevel = kPiwigoPrivacyEverybody;
        instance.stripGPSdataOnUpload = NO;         // Upload images with private metadata
        instance.photoQuality = 95;                 // 95% image quality at compression
        instance.photoResize = 100;                 // Do not resize images
        instance.deleteImageAfterUpload = NO;
        instance.prefixFileNameBeforeUpload = NO;
        instance.defaultPrefix = @"";
        instance.localImagesSort = kPiwigoSortDateCreatedDescending;    // i.e. new to old
        instance.wifiOnlyUploading = NO;            // Wi-Fi only option

        // Default palette mode
        instance.isDarkPaletteActive = NO;
        instance.switchPaletteAutomatically = YES;
        instance.switchPaletteThreshold = 40;
        instance.isLightPaletteModeActive = NO;
        instance.isDarkPaletteModeActive = NO;
        instance.isSystemDarkModeActive = NO;
        
        // Default cache settings
        instance.loadAllCategoryInfo = YES;         // Load all albums data at start
		instance.diskCache = kPiwigoDiskCacheMin * 4;       // i.e. 512 MB
		instance.memoryCache = kPiwigoMemoryCacheInc * 2;   // i.e. 16 MB
		
        // Remember which help views were watched
        instance.didWatchHelpViews = 0b0000000000000000;
        
        // Request help for translating Piwigo every 2 weeks or so
        instance.dateOfLastTranslationRequest = [[NSDate date] timeIntervalSinceReferenceDate] - k2WeeksInDays;

        [instance readFromDisk];
	});
	return instance;
}

-(NSString *)getNameForPrivacyLevel:(kPiwigoPrivacy)privacyLevel
{
	NSString *name = @"";
	switch(privacyLevel)
	{
		case kPiwigoPrivacyAdmins:
			name = NSLocalizedString(@"privacyLevel_admin", @"Admins");
			break;
		case kPiwigoPrivacyAdminsFamily:
			name = NSLocalizedString(@"privacyLevel_adminFamily", @"Admins, Family");
			break;
		case kPiwigoPrivacyAdminsFamilyFriends:
			name = NSLocalizedString(@"privacyLevel_adminsFamilyFriends", @"Admins, Family, Friends");
			break;
		case kPiwigoPrivacyAdminsFamilyFriendsContacts:
			name = NSLocalizedString(@"privacyLevel_adminsFamilyFriendsContacts", @"Admins, Family, Friends, Contacts");
			break;
		case kPiwigoPrivacyEverybody:
			name = NSLocalizedString(@"privacyLevel_everybody", @"Everybody");
			break;
            
		case kPiwigoPrivacyCount:
        case kPiwigoPrivacyUnknown:
			break;
	}
	
	return name;
}


#pragma mark - Getter

-(NSInteger)photoResize {
    if (_photoResize < 5) {
        _photoResize = 5;
    } else if (_photoResize > 100) {
        _photoResize = 100;
    }
    return _photoResize;
}

-(NSInteger)photoQuality {
    if (_photoQuality < 50) {
        _photoQuality = 50;
    } else if (_photoQuality > 100) {
        _photoQuality = 100;
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
		self.serverProtocol = modelData.serverProtocol;
		self.serverPath = modelData.serverPath;
		self.defaultPrivacyLevel = modelData.defaultPrivacyLevel;
		self.defaultAuthor = modelData.defaultAuthor;
		self.diskCache = modelData.diskCache;
		self.memoryCache = modelData.memoryCache;
		self.photoQuality = modelData.photoQuality;
		self.photoResize = modelData.photoResize;
		self.loadAllCategoryInfo = modelData.loadAllCategoryInfo;
		self.defaultSort = modelData.defaultSort;
		self.resizeImageOnUpload = modelData.resizeImageOnUpload;
		self.defaultImagePreviewSize = modelData.defaultImagePreviewSize;
        self.stripGPSdataOnUpload = modelData.stripGPSdataOnUpload;
        self.defaultThumbnailSize = modelData.defaultThumbnailSize;
        self.displayImageTitles = modelData.displayImageTitles;
        self.compressImageOnUpload = modelData.compressImageOnUpload;
        self.deleteImageAfterUpload = modelData.deleteImageAfterUpload;
        self.username = modelData.username;
        self.HttpUsername = modelData.HttpUsername;
        self.isDarkPaletteActive = modelData.isDarkPaletteActive;
        self.switchPaletteAutomatically = modelData.switchPaletteAutomatically;
        self.switchPaletteThreshold = modelData.switchPaletteThreshold;
        self.isDarkPaletteModeActive = modelData.isDarkPaletteModeActive;
        self.thumbnailsPerRowInPortrait = modelData.thumbnailsPerRowInPortrait;
        self.defaultCategory = modelData.defaultCategory;
        self.dateOfLastTranslationRequest = modelData.dateOfLastTranslationRequest;
        self.couldNotMigrateCoreDataStore = modelData.couldNotMigrateCoreDataStore;
        self.shareMetadataTypeAirDrop = modelData.shareMetadataTypeAirDrop;
        self.shareMetadataTypeAssignToContact = modelData.shareMetadataTypeAssignToContact;
        self.shareMetadataTypeCopyToPasteboard = modelData.shareMetadataTypeCopyToPasteboard;
        self.shareMetadataTypeMail = modelData.shareMetadataTypeMail;
        self.shareMetadataTypeMessage = modelData.shareMetadataTypeMessage;
        self.shareMetadataTypePostToFacebook = modelData.shareMetadataTypePostToFacebook;
        self.shareMetadataTypeMessenger = modelData.shareMetadataTypeMessenger;
        self.shareMetadataTypePostToFlickr = modelData.shareMetadataTypePostToFlickr;
        self.shareMetadataTypePostInstagram = modelData.shareMetadataTypePostInstagram;
        self.shareMetadataTypePostToSignal = modelData.shareMetadataTypePostToSignal;
        self.shareMetadataTypePostToSnapchat = modelData.shareMetadataTypePostToSnapchat;
        self.shareMetadataTypePostToTencentWeibo = modelData.shareMetadataTypePostToTencentWeibo;
        self.shareMetadataTypePostToTwitter = modelData.shareMetadataTypePostToTwitter;
        self.shareMetadataTypePostToVimeo = modelData.shareMetadataTypePostToVimeo;
        self.shareMetadataTypePostToWeibo = modelData.shareMetadataTypePostToWeibo;
        self.shareMetadataTypePostToWhatsApp = modelData.shareMetadataTypePostToWhatsApp;
        self.shareMetadataTypeSaveToCameraRoll = modelData.shareMetadataTypeSaveToCameraRoll;
        self.shareMetadataTypeOther = modelData.shareMetadataTypeOther;
        self.uploadChunkSize = modelData.uploadChunkSize;
        self.stringEncoding = modelData.stringEncoding;
        self.defaultAlbumThumbnailSize = modelData.defaultAlbumThumbnailSize;
        self.recentCategories = modelData.recentCategories;
        self.maxNberRecentCategories = modelData.maxNberRecentCategories;
        self.prefixFileNameBeforeUpload = modelData.prefixFileNameBeforeUpload;
        self.defaultPrefix = modelData.defaultPrefix;
        self.localImagesSort = modelData.localImagesSort;
        self.wifiOnlyUploading = modelData.wifiOnlyUploading;
        self.didWatchHelpViews = modelData.didWatchHelpViews;
	}
}

- (void)saveToDisk
{
	NSString *dataPath = [Model applicationDocumentsDirectory];
	NSMutableData *data = [[NSMutableData alloc] init];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	[archiver encodeObject:self forKey:@"Model"];
	[archiver finishEncoding];
	[data writeToFile:dataPath atomically:YES];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	NSMutableArray *saveObject = [[NSMutableArray alloc] init];
	[saveObject addObject:self.serverPath];
	[saveObject addObject:@(self.defaultPrivacyLevel)];
	[saveObject addObject:self.defaultAuthor];
	[saveObject addObject:@(self.diskCache)];
	[saveObject addObject:@(self.memoryCache)];
	[saveObject addObject:@(self.photoQuality)];
	[saveObject addObject:@(self.photoResize)];
	[saveObject addObject:self.serverProtocol];
	[saveObject addObject:[NSNumber numberWithBool:self.loadAllCategoryInfo]];
	[saveObject addObject:@(self.defaultSort)];
	[saveObject addObject:[NSNumber numberWithBool:self.resizeImageOnUpload]];
	[saveObject addObject:@(self.defaultImagePreviewSize)];
    [saveObject addObject:[NSNumber numberWithBool:self.stripGPSdataOnUpload]];
    [saveObject addObject:@(self.defaultThumbnailSize)];
    [saveObject addObject:@(self.displayImageTitles)];
    // Added in v2.1.5…
    [saveObject addObject:[NSNumber numberWithBool:self.compressImageOnUpload]];
    [saveObject addObject:[NSNumber numberWithBool:self.deleteImageAfterUpload]];
    // Added in v2.1.6…
    [saveObject addObject:self.username];
    [saveObject addObject:self.HttpUsername];
    [saveObject addObject:[NSNumber numberWithBool:self.isDarkPaletteActive]];
    [saveObject addObject:[NSNumber numberWithBool:self.switchPaletteAutomatically]];
    [saveObject addObject:@(self.switchPaletteThreshold)];
    [saveObject addObject:[NSNumber numberWithBool:self.isDarkPaletteModeActive]];
    // Added in v2.1.8…
    [saveObject addObject:[NSNumber numberWithInteger:self.thumbnailsPerRowInPortrait]];
    // Added in v2.2.0…
    [saveObject addObject:[NSNumber numberWithInteger:self.defaultCategory]];
    // Added in v2.2.3…
    [saveObject addObject:[NSNumber numberWithDouble:self.dateOfLastTranslationRequest]];
    // Added in v2.2.5…
    [saveObject addObject:[NSNumber numberWithBool:self.couldNotMigrateCoreDataStore]];
    // Added in v2.3…
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeAirDrop]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeAssignToContact]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeCopyToPasteboard]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeMail]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeMessage]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToFacebook]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeMessenger]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToFlickr]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostInstagram]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToSignal]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToSnapchat]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToTencentWeibo]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToTwitter]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToVimeo]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToWeibo]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypePostToWhatsApp]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeSaveToCameraRoll]];
    [saveObject addObject:[NSNumber numberWithBool:self.shareMetadataTypeOther]];
    // Added in v2.4.1…
    [saveObject addObject:[NSNumber numberWithInteger:self.uploadChunkSize]];
    [saveObject addObject:[NSNumber numberWithUnsignedInteger:self.stringEncoding]];
    // Added in v2.4.2…
    [saveObject addObject:[NSNumber numberWithInteger:self.defaultAlbumThumbnailSize]];
    // Added in v2.4.5…
    [saveObject addObject:self.recentCategories];
    [saveObject addObject:[NSNumber numberWithUnsignedInteger:self.maxNberRecentCategories]];
    // Added in 2.4.6…
    [saveObject addObject:[NSNumber numberWithBool:self.prefixFileNameBeforeUpload]];
    [saveObject addObject:self.defaultPrefix];
    // Added in 2.5.0…
    [saveObject addObject:@(self.localImagesSort)];
    [saveObject addObject:[NSNumber numberWithBool:self.wifiOnlyUploading]];
    // Added in 2.5.3…
    [saveObject addObject:[NSNumber numberWithInteger:self.didWatchHelpViews]];

    [encoder encodeObject:saveObject forKey:@"Model"];
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
	self.defaultPrivacyLevel = (kPiwigoPrivacy)[[savedData objectAtIndex:1] integerValue];
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
		self.loadAllCategoryInfo = [[savedData objectAtIndex:8] boolValue];
	} else {
		self.loadAllCategoryInfo = YES;
	}
	if(savedData.count > 9) {
		self.defaultSort = (kPiwigoSort)[[savedData objectAtIndex:9] intValue];
	} else {
		self.defaultSort = kPiwigoSortDateCreatedAscending;
	}
	if(savedData.count > 10) {
		self.resizeImageOnUpload = [[savedData objectAtIndex:10] boolValue];
	} else {
		self.resizeImageOnUpload = NO;
        self.photoResize = 100;
	}
    if(savedData.count > 11) {
        if(savedData.count > 47) {
            self.defaultImagePreviewSize = [[savedData objectAtIndex:11] integerValue];
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
        self.defaultAlbumThumbnailSize = [[savedData objectAtIndex:47] integerValue];
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
        self.localImagesSort = (kPiwigoSort)[[savedData objectAtIndex:52] intValue];
    } else {
        self.localImagesSort = kPiwigoSortDateCreatedDescending;
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
	return self;
}

@end
