//
//  ImageUpload.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUpload.h"

@implementation ImageUpload

-(instancetype)initWithImageName:(NSString*)imageName forCategory:(NSInteger)category forPrivacyLevel:(NSInteger)privacy
{
	self = [super init];
	if(self)
	{
		self.imageUploadName = imageName;
		self.categoryToUploadTo = category;
		self.privacyLevel = privacy;
	}
	return self;
}

-(instancetype)initWithImageName:(NSString*)imageName forCategory:(NSInteger)category forPrivacyLevel:(NSInteger)privacy author:(NSString*)author description:(NSString*)description andTags:(NSString*)tags
{
	self = [self initWithImageName:imageName forCategory:category forPrivacyLevel:privacy];
	if(self)
	{
		self.author = author;
		self.imageDescription = description;
		self.tags = tags;
	}
	return self;
}

@end
