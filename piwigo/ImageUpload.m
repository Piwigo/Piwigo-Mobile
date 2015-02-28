//
//  ImageUpload.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUpload.h"
#import "PiwigoImageData.h"

@implementation ImageUpload

-(instancetype)initWithImageName:(NSString*)imageName forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy
{
	self = [super init];
	if(self)
	{
		self.image = imageName;
		self.imageUploadName = imageName;
		self.categoryToUploadTo = category;
		self.privacyLevel = privacy;
	}
	return self;
}

-(instancetype)initWithImageName:(NSString*)imageName forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy author:(NSString*)author description:(NSString*)description andTags:(NSArray*)tags
{
	self = [self initWithImageName:imageName forCategory:category forPrivacyLevel:privacy];
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
	self = [self initWithImageName:imageData.name forCategory:[[[imageData categoryIds] firstObject] integerValue] forPrivacyLevel:(kPiwigoPrivacy)imageData.privacyLevel author:imageData.author description:imageData.imageDescription andTags:imageData.tags];
	if(self)
	{
		self.imageId = [imageData.imageId integerValue];
	}
	return self;
}

@end
