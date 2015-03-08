//
//  Model.m
//  piwigo
//
//  Created by Spencer Baker on 9/10/14.
//  Copyright (c) 2014 CS 3450. All rights reserved.
//

#import "Model.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface Model()

@end

@implementation Model

+ (Model*)sharedInstance
{
	static Model *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		
		instance.imagesPerPage = 100;
		instance.defaultPrivacyLevel = 0;
		instance.defaultAuthor = @"";
		instance.hasAdminRights = NO;
		
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
		self.serverName = modelData.serverName;
		self.defaultPrivacyLevel = modelData.defaultPrivacyLevel;
		self.defaultAuthor = modelData.defaultAuthor;
		
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
	
	[encoder encodeObject:saveObject forKey:@"Model"];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	NSArray *savedData = [decoder decodeObjectForKey:@"Model"];
	self.serverName = [savedData objectAtIndex:0];
	self.defaultPrivacyLevel = (kPiwigoPrivacy)[[savedData objectAtIndex:1] integerValue];
	self.defaultAuthor = [savedData objectAtIndex:2];
	
	return self;
}

@end
