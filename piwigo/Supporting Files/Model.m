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

NSInteger const kPiwigoMinMemoryCache = 32;     // Min size and slider increment
NSInteger const kPiwigoMinDiskCache   = 128;    // 32 MB memory cache, 128 MB disk cache
NSInteger const kPiwigoMaxMemoryCache = 512;    // Max size
NSInteger const kPiwigoMaxDiskCache   = 2048;   // 512 MB memory cache, 2 GB disk cache

NSTimeInterval const k1WeekInDays  = 60 * 60 * 24 *  7.0;
NSTimeInterval const k2WeeksInDays = 60 * 60 * 24 * 14.0;
NSTimeInterval const k3WeeksInDays = 60 * 60 * 24 * 21.0;

NSString *kPiwigoActivityTypeMessenger = @"com.facebook.Messenger.ShareExtension";
NSString *kPiwigoActivityTypePostInstagram = @"com.burbn.instagram.shareextension";
NSString *kPiwigoActivityTypePostToSignal = @"org.whispersystems.signal.shareextension";
NSString *kPiwigoActivityTypePostToSnapchat = @"com.toyopagroup.picaboo.share";
NSString *kPiwigoActivityTypePostToWhatsApp = @"net.whatsapp.WhatsApp.ShareExtension";
NSString *kPiwigoActivityTypeOther = @"undefined.ShareExtension";

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
        instance.stringEncoding = NSUTF8StringEncoding; // UTF-8 by default
        instance.username = @"";
        instance.HttpUsername = @"";
		instance.hasAdminRights = NO;
        instance.hadOpenedSession = NO;
        instance.hasUploadedImages = NO;
        instance.usesCommunityPluginV29 = NO;           // Checked at each new session
        instance.performedHTTPauthentication = NO;      // Checked at each new session
        instance.userCancelledCommunication = NO;

        // Album/category settings
        instance.defaultCategory = 0;                   // Root album by default
        instance.defaultAlbumThumbnailSize = [PiwigoImageData optimumAlbumThumbnailSizeForDevice];

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
        
        // Optimised image thumbnail size, will be cross-checked at login
        instance.defaultThumbnailSize = [PiwigoImageData optimumImageThumbnailSizeForDevice];
        instance.thumbnailsPerRowInPortrait = [ImagesCollection imagesPerRowInPortraitForView:nil maxWidth:[PiwigoImageData widthForImageSizeType:(kPiwigoImageSize)instance.defaultThumbnailSize]];

        // Default image settings
        instance.didOptimiseImagePreviewSize = NO;  // ===> Unused and therefore available…
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

        // Default palette mode
        instance.isDarkPaletteActive = NO;
        instance.switchPaletteAutomatically = NO;
        instance.switchPaletteThreshold = 50;
        instance.isDarkPaletteModeActive = NO;
        
        // Default cache settings
        instance.loadAllCategoryInfo = YES;         // Load all albums data at start
		instance.diskCache = kPiwigoMinDiskCache * 4;
		instance.memoryCache = kPiwigoMinMemoryCache * 4;
		
        // Request help for translating Piwigo every 2 weeks or so
        instance.dateOfLastTranslationRequest = [[NSDate date] timeIntervalSinceReferenceDate] - k2WeeksInDays;

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

-(NSString *)getNameForPrivacyLevel:(NSInteger)privacyLevel
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
        case NSNotFound:
            name = @"";
            break;
			
		case kPiwigoPrivacyCount:
			break;
	}
	
	return name;
}

-(NSString *)getNameForShareActivity:(NSString *)activity forWidth:(CGFloat)width
{
    NSString *name = @"";
    if ([activity isEqualToString:UIActivityTypeAirDrop]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_AirDrop>375px", @"Transfer images with AirDrop") : NSLocalizedString(@"shareActivityCode_AirDrop", @"Transfer with AirDrop");
    } else if ([activity isEqualToString:UIActivityTypeAssignToContact]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_AssignToContact>375px", @"Assign image to contact") : NSLocalizedString(@"shareActivityCode_AssignToContact", @"Assign to contact");
    } else if ([activity isEqualToString:UIActivityTypeCopyToPasteboard]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_CopyToPasteboard>375px", @"Copy images to Pasteboard") : NSLocalizedString(@"shareActivityCode_CopyToPasteboard", @"Copy to Pasteboard");
    } else if ([activity isEqualToString:UIActivityTypeMail]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Mail>375px", @"Post images by email") : NSLocalizedString(@"shareActivityCode_Mail", @"Post by email");
    } else if ([activity isEqualToString:UIActivityTypeMessage]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Message>375px", @"Post images with the Message app") : NSLocalizedString(@"shareActivityCode_Message", @"Post with Message");
    } else if ([activity isEqualToString:UIActivityTypePostToFacebook]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Facebook>375px", @"Post images to Facebook") : NSLocalizedString(@"shareActivityCode_Facebook", @"Post to Facebook");
    } else if ([activity isEqualToString:kPiwigoActivityTypeMessenger]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Messenger>375px", @"Post images with the Messenger app") : NSLocalizedString(@"shareActivityCode_Messenger", @"Post with Messenger");
    } else if ([activity isEqualToString:UIActivityTypePostToFlickr]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Flickr>375px", @"Post images to Flickr") : NSLocalizedString(@"shareActivityCode_Flickr", @"Post to Flickr");
    } else if ([activity isEqualToString:kPiwigoActivityTypePostInstagram]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Instagram>375px", @"Post images to Instagram") : NSLocalizedString(@"shareActivityCode_Instagram", @"Post to Instagram");
    } else if ([activity isEqualToString:kPiwigoActivityTypePostToSignal]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Signal>375px", @"Post images with the Signal app") : NSLocalizedString(@"shareActivityCode_Signal", @"Post with Signal");
    } else if ([activity isEqualToString:kPiwigoActivityTypePostToSnapchat]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Snapchat>375px", @"Post images to Snapchat app") : NSLocalizedString(@"shareActivityCode_Snapchat", @"Post to Snapchat");
    } else if ([activity isEqualToString:UIActivityTypePostToTencentWeibo]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_TencentWeibo>375px", @"Post images to TencentWeibo") : NSLocalizedString(@"shareActivityCode_TencentWeibo", @"Post to TencentWeibo");
    } else if ([activity isEqualToString:UIActivityTypePostToTwitter]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Twitter>375px", @"Post images to Twitter") : NSLocalizedString(@"shareActivityCode_Twitter", @"Post to Twitter");
    } else if ([activity isEqualToString:UIActivityTypePostToVimeo]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Vimeo>375px", @"Post videos to Vimeo") : NSLocalizedString(@"shareActivityCode_Vimeo", @"Post to Vimeo");
    } else if ([activity isEqualToString:UIActivityTypePostToWeibo]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Weibo>375px", @"Post images to Weibo") : NSLocalizedString(@"shareActivityCode_Weibo", @"Post to Weibo");
    } else if ([activity isEqualToString:kPiwigoActivityTypePostToWhatsApp]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_WhatsApp>375px", @"Post images with the WhatsApp app") : NSLocalizedString(@"shareActivityCode_WhatsApp", @"Post with WhatsApp");
    } else if ([activity isEqualToString:UIActivityTypeSaveToCameraRoll]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_CameraRoll>375px", @"Save images to Camera Roll") : NSLocalizedString(@"shareActivityCode_CameraRoll", @"Save to Camera Roll");
    } else if ([activity isEqualToString:kPiwigoActivityTypeOther]) {
        name = width > 375 ? NSLocalizedString(@"shareActivityCode_Other>375px", @"Share images with other apps") : NSLocalizedString(@"shareActivityCode_Other", @"Share with other apps");
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
        self.defaultCategory = modelData.defaultCategory;
        self.dateOfLastTranslationRequest = modelData.dateOfLastTranslationRequest;
        self.didOptimiseImagePreviewSize = modelData.didOptimiseImagePreviewSize;  // ===> Unused
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
    [saveObject addObject:@(self.thumbnailsPerRowInPortrait)];
    // Added in v2.2.0…
    [saveObject addObject:@(self.defaultCategory)];
    // Added in v2.2.3…
    [saveObject addObject:[NSNumber numberWithDouble:self.dateOfLastTranslationRequest]];
    // Added in v2.2.5…
    [saveObject addObject:[NSNumber numberWithBool:self.didOptimiseImagePreviewSize]];  // ===> Unused
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
    
    [encoder encodeObject:saveObject forKey:@"Model"];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	NSArray *savedData = [decoder decodeObjectForKey:@"Model"];
	self.serverName = [savedData objectAtIndex:0];
	self.defaultPrivacyLevel = (kPiwigoPrivacy)[[savedData objectAtIndex:1] integerValue];
	self.defaultAuthor = [savedData objectAtIndex:2];

    self.diskCache = MAX([[savedData objectAtIndex:3] integerValue], kPiwigoMinDiskCache * 4);
    self.diskCache = MIN(self.diskCache, kPiwigoMaxDiskCache);
	self.memoryCache = MAX([[savedData objectAtIndex:4] integerValue], kPiwigoMinMemoryCache * 4);
    self.memoryCache = MIN(self.memoryCache, kPiwigoMaxMemoryCache);

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
            self.defaultThumbnailSize = [[savedData objectAtIndex:13] integerValue];
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
    NSInteger nberOfImages = [ImagesCollection imagesPerRowInPortraitForView:nil maxWidth:[PiwigoImageData widthForImageSizeType:(kPiwigoImageSize)self.defaultThumbnailSize]];
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
    if(savedData.count > 26) {  // ===> Unused and therefore available…
        self.didOptimiseImagePreviewSize = NO;
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
	return self;
}

@end
