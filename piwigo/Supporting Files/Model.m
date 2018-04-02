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
        instance.serverName = @"";
        instance.username = @"";
        instance.HttpUsername = @"";
		instance.imagesPerPage = 100;
		instance.defaultPrivacyLevel = kPiwigoPrivacyEverybody;
		instance.defaultAuthor = @"";
		instance.hasAdminRights = NO;
        instance.hadOpenedSession = NO;
        instance.hasUploadedImages = NO;
        instance.usesCommunityPluginV29 = NO;           // Checked at each new session
        instance.performedHTTPauthentication = NO;      // Checked at each new session
        instance.userCancelledCommunication = NO;
        instance.deleteImageAfterUpload = NO;
        
        // Load all albums data at start
		instance.loadAllCategoryInfo = YES;
        
        // Sort images by date: old to new
		instance.defaultSort = kPiwigoSortCategoryDateCreatedAscending;
        
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
        
        // Default thumbnail size and number per row in portrait mode
        instance.defaultThumbnailSize = kPiwigoImageSizeThumb;
        instance.thumbnailsPerRowInPortrait = roundf(1.5 * [ImagesCollection numberOfImagesPerRowForViewInPortrait:nil withMaxWidth:(float)kThumbnailFileSize]);
        
        // Default image preview size
		instance.defaultImagePreviewSize = kPiwigoImageSizeMedium;
        
        // Default palette mode
        instance.isDarkPaletteActive = NO;
        instance.switchPaletteAutomatically = NO;
        instance.switchPaletteThreshold = 50;
        instance.isDarkPaletteModeActive = NO;
        
        // Default image upload setting
        instance.stripGPSdataOnUpload = NO;         // Upload images with private metadata
		instance.photoQuality = 95;                 // 95% image quality at compression
		instance.photoResize = 100;                 // Do not resize images
        
        // Defaults caches sizes
		instance.diskCache = 80;
		instance.memoryCache = 80;
		
		[instance readFromDisk];
	});
	return instance;
}

+ (PHPhotoLibrary *)defaultAssetsLibrary
{
    static dispatch_once_t pred = 0;
    static PHPhotoLibrary *library = nil;
    dispatch_once(&pred, ^{
        library = [[PHPhotoLibrary alloc] init];
    });
    return library;
}

-(NSString*)getNameForPrivacyLevel:(kPiwigoPrivacy)privacyLevel
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
			break;
	}
	
	return name;
}

#pragma mark - Getter -

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
		self.serverName = modelData.serverName;
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

- (void) encodeWithCoder:(NSCoder *)encoder {
	NSMutableArray *saveObject = [[NSMutableArray alloc] init];
	[saveObject addObject:self.serverName];
	[saveObject addObject:@(self.defaultPrivacyLevel)];
	[saveObject addObject:self.defaultAuthor];
	[saveObject addObject:@(self.diskCache)];
	[saveObject addObject:@(self.memoryCache)];
	[saveObject addObject:@(self.photoQuality)];
	[saveObject addObject:@(self.photoResize)];
	[saveObject addObject:self.serverProtocol];
	[saveObject addObject:[NSNumber numberWithBool:self.loadAllCategoryInfo]];
	[saveObject addObject:@(self.defaultSort)];
	[saveObject addObject:[ NSNumber numberWithBool:self.resizeImageOnUpload]];
	[saveObject addObject:@(self.defaultImagePreviewSize)];
    [saveObject addObject:[NSNumber numberWithBool:self.stripGPSdataOnUpload]];
    [saveObject addObject:@(self.defaultThumbnailSize)];
    [saveObject addObject:@(self.displayImageTitles)];
    [saveObject addObject:[NSNumber numberWithBool:self.compressImageOnUpload]];    // Added in v2.1.5
    [saveObject addObject:[NSNumber numberWithBool:self.deleteImageAfterUpload]];
    [saveObject addObject:self.username];                                           // Added in v2.1.6
    [saveObject addObject:self.HttpUsername];
    [saveObject addObject:[NSNumber numberWithBool:self.isDarkPaletteActive]];
    [saveObject addObject:[NSNumber numberWithBool:self.switchPaletteAutomatically]];
    [saveObject addObject:@(self.switchPaletteThreshold)];
    [saveObject addObject:[NSNumber numberWithBool:self.isDarkPaletteModeActive]];
    [saveObject addObject:@(self.thumbnailsPerRowInPortrait)];                      // Added in v2.1.8
	
	[encoder encodeObject:saveObject forKey:@"Model"];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	NSArray *savedData = [decoder decodeObjectForKey:@"Model"];
	self.serverName = [savedData objectAtIndex:0];
	self.defaultPrivacyLevel = (kPiwigoPrivacy)[[savedData objectAtIndex:1] integerValue];
	self.defaultAuthor = [savedData objectAtIndex:2];
	self.diskCache = [[savedData objectAtIndex:3] integerValue];
	self.memoryCache = [[savedData objectAtIndex:4] integerValue];
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
		self.defaultSort = (kPiwigoSortCategory)[[savedData objectAtIndex:9] intValue];
	} else {
		self.defaultSort = kPiwigoSortCategoryDateCreatedAscending;
	}
	if(savedData.count > 10) {
		self.resizeImageOnUpload = [[savedData objectAtIndex:10] boolValue];
	} else {
		self.resizeImageOnUpload = NO;
        self.photoResize = 100;
	}
	if(savedData.count > 11) {
		self.defaultImagePreviewSize = [[savedData objectAtIndex:11] integerValue];
	} else {
		self.defaultImagePreviewSize = kPiwigoImageSizeMedium;
	}
	if(savedData.count > 12) {
		self.stripGPSdataOnUpload = [[savedData objectAtIndex:12] boolValue];
	} else {
		self.stripGPSdataOnUpload = NO;
	}
	if(savedData.count > 13) {
		self.defaultThumbnailSize = [[savedData objectAtIndex:13] integerValue];
	} else {
		self.defaultThumbnailSize = kPiwigoImageSizeThumb;
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
        self.switchPaletteAutomatically = NO;
    }
    if(savedData.count > 21) {
        self.switchPaletteThreshold = [[savedData objectAtIndex:21] integerValue];
    } else {
        self.switchPaletteThreshold = 50;
    }
    if(savedData.count > 22) {
        self.isDarkPaletteModeActive = [[savedData objectAtIndex:22] boolValue];
    } else {
        self.isDarkPaletteModeActive = NO;
    }
    if(savedData.count > 23) {
        self.thumbnailsPerRowInPortrait = [[savedData objectAtIndex:23] integerValue];
    } else {
        self.thumbnailsPerRowInPortrait = 4;
    }
	return self;
}

@end
