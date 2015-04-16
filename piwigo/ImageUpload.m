//
//  ImageUpload.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUpload.h"
#import "PiwigoImageData.h"
#import <AssetsLibrary/AssetsLibrary.h>

@implementation ImageUpload

-(instancetype)initWithImageAsset:(ALAsset*)imageAsset forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy
{
	self = [super init];
	if(self)
	{
		self.imageAsset = imageAsset;
		self.image = [[imageAsset defaultRepresentation] filename];
		self.imageUploadName = [[imageAsset defaultRepresentation] filename];
		self.categoryToUploadTo = category;
		self.privacyLevel = privacy;
	}
	return self;
}

-(instancetype)initWithImageAsset:(ALAsset*)imageAsset forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy author:(NSString*)author description:(NSString*)description andTags:(NSArray*)tags
{
	self = [self initWithImageAsset:imageAsset forCategory:category forPrivacyLevel:privacy];
	if(self)
	{
		if([description isKindOfClass:[NSNull class]])
		{
			description = nil;
		}
		
		self.author = author;
		self.imageDescription = description;
		self.tags = tags;
	}
	return self;
}

-(instancetype)initWithImageData:(PiwigoImageData*)imageData
{
	self = [self initWithImageAsset:nil forCategory:[[[imageData categoryIds] firstObject] integerValue] forPrivacyLevel:(kPiwigoPrivacy)imageData.privacyLevel author:imageData.author description:imageData.imageDescription andTags:imageData.tags];
	self.image = imageData.fileName;
	self.imageUploadName = imageData.name;
	if(self)
	{
		self.imageId = [imageData.imageId integerValue];
	}
	return self;
}

@end
