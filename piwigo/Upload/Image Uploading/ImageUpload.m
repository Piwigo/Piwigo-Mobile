//
//  ImageUpload.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "ImageUpload.h"
#import "PiwigoImageData.h"

@implementation ImageUpload

-(instancetype)initWithImageAsset:(PHAsset*)imageAsset forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy
{
	self = [super init];
	if(self)
	{
		self.imageAsset = imageAsset;
        if (imageAsset) {
            NSArray *resources = [PHAssetResource assetResourcesForAsset:imageAsset];
            self.image = ((PHAssetResource*)resources[0]).originalFilename;
            self.title = [((PHAssetResource*)resources[0]).originalFilename stringByDeletingPathExtension];
        } else {
            self.image = @"";
            self.title = @"";
        }
        self.categoryToUploadTo = category;
        self.privacyLevel = privacy;
	}
	return self;
}

-(instancetype)initWithImageAsset:(PHAsset*)imageAsset forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy author:(NSString*)author description:(NSString*)description andTags:(NSArray*)tags
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
        if (tags == nil) {
            self.tags = [[NSArray alloc] init];     // New images have no tags
        } else {
            self.tags = tags;
        }
	}
	return self;
}

-(instancetype)initWithImageData:(PiwigoImageData*)imageData
{
	self = [self initWithImageAsset:nil forCategory:[[[imageData categoryIds] firstObject] integerValue] forPrivacyLevel:(kPiwigoPrivacy)imageData.privacyLevel author:imageData.author description:imageData.imageDescription andTags:imageData.tags];
	self.image = imageData.fileName;
	self.title = imageData.name;
	if(self)
	{
		self.imageId = [imageData.imageId integerValue];
	}
	return self;
}

-(NSString *)author {
    if (nil == _author) {
        _author = @"";
    }
    return _author;
}

-(NSString *)imageDescription {
    if (nil == _imageDescription) {
        _imageDescription = @"";
    }
    return _imageDescription;
}

-(NSString *)title {
    if (nil == _title) {
        _title = @"";
    }
    return _title;
}

#pragma mark - debugging support -

-(NSString *)description {
    NSString *objectIsNil = @"<nil>";
    
    NSMutableArray * descriptionArray = [[NSMutableArray alloc] init];
    [descriptionArray addObject:[NSString stringWithFormat:@"<%@: 0x%lx> = {", [self class], (unsigned long)self]];
    PHImageRequestOptions * imageRequestOptions = [[PHImageRequestOptions alloc] init];
    [[PHImageManager defaultManager] requestImageDataForAsset:self.imageAsset
                                                      options:imageRequestOptions
                                                resultHandler:^(NSData *imageData, NSString *dataUTI,
                                                                UIImageOrientation orientation,NSDictionary *info)
                     {
                         NSLog(@"info = %@", info);
                         if ([info objectForKey:@"PHImageFileURLKey"]) {
                             NSURL *url = [info objectForKey:@"PHImageFileURLKey"];
                             [descriptionArray addObject:[NSString stringWithFormat:@"imageAsset         = %@", url]];
                         }
                     }
    ];

    [descriptionArray addObject:[NSString stringWithFormat:@"image              = %@", (nil == self.image ? objectIsNil :(0 == self.image.length ? @"''" : self.image))]];
    [descriptionArray addObject:[NSString stringWithFormat:@"title    = %@", (nil == self.title ? objectIsNil : (0 == self.title.length ? @"''" : self.title))]];
    
    [descriptionArray addObject:[NSString stringWithFormat:@"categoryToUploadTo = %ld", (long)self.categoryToUploadTo]];
    [descriptionArray addObject:[NSString stringWithFormat:@"privacyLevel       = %@", kPiwigoPrivacyString(self.privacyLevel)]];
    [descriptionArray addObject:[NSString stringWithFormat:@"imageDescription   = %@", (nil == self.imageDescription ? objectIsNil :(0 == [self.imageDescription length] ? @"''" : self.imageDescription))]];

    [descriptionArray addObject:[NSString stringWithFormat:@"tags [%ld] %@", (long)self.tags.count, self.tags]];
    [descriptionArray addObject:[NSString stringWithFormat:@"imageId            = %ld", (long)self.imageId]];


    [descriptionArray addObject:@"}"];
    
    return [descriptionArray componentsJoinedByString:@"\n"];
}

    
@end
