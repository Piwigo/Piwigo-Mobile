//
//  Model.m
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import "Model.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "PiwigoImageData.h"

@interface Model()

@end

@implementation Model

+ (Model*)sharedInstance
{
	static Model *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.serverProtocol = @"https://";
		instance.imagesPerPage = 100;
		instance.defaultPrivacyLevel = kPiwigoPrivacyEverybody;
		instance.defaultAuthor = @"";
		instance.hasAdminRights = NO;
		instance.photoQuality = 95;
		instance.photoResize = 100;
		instance.defaultImagePreviewSize = kPiwigoImageSizeMedium;
		
		instance.diskCache = 10;
		instance.memoryCache = 80;
		
		instance.loadAllCategoryInfo = YES;
		instance.defaultSort = kPiwigoSortCategoryIdDescending;
		
		[instance readFromDisk];
	});
	return instance;
}

+ (ALAssetsLibrary *)defaultAssetsLibrary
{
	static dispatch_once_t pred = 0;
	static ALAssetsLibrary *library = nil;
	dispatch_once(&pred, ^{
		library = [[ALAssetsLibrary alloc] init];
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
    if (_photoResize < 1) {
        _photoResize = 1;
    } else if (_photoResize > 100) {
        _photoResize = 100;
    }
    return _photoResize;
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
		self.defaultSort = kPiwigoSortCategoryIdDescending;
	}
	if(savedData.count > 10) {
		self.resizeImageOnUpload = [[savedData objectAtIndex:10] boolValue];
	} else {
		self.resizeImageOnUpload = NO;
		self.photoQuality = 95;
	}
	if(savedData.count > 11) {
		self.defaultImagePreviewSize = [[savedData objectAtIndex:11] integerValue];
	} else {
		self.defaultImagePreviewSize = kPiwigoImageSizeMedium;
	}
	
	return self;
}

@end
