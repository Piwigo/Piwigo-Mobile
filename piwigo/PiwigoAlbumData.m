//
//  PiwigoAlbumData.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoAlbumData.h"

@interface PiwigoAlbumData()

@property (nonatomic, strong) NSArray *imageList;
@property (nonatomic, strong) NSDictionary *imageNameList;

@end

@implementation PiwigoAlbumData

-(void)addImages:(NSArray*)images
{
	NSMutableArray *newImageList = [[NSMutableArray alloc] initWithArray:self.imageList];
	NSMutableDictionary *newImageNameList = [[NSMutableDictionary alloc] initWithDictionary:self.imageNameList];
	for(PiwigoImageData *imageData in images)
	{
		[newImageList addObject:imageData];
		[newImageNameList setObject:imageData.imageId forKey:imageData.fileName];
	}
	self.imageList = newImageList;
	self.imageNameList = newImageNameList;
	
	self.allKeysOrdered = [self.imageNameList.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
//	[self sortImageList:ImageListOrderId];
}

-(void)sortImageList:(ImageListOrder)order
{
	// @TODO: change sort based on enum
	self.imageList = [self.imageList sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		PiwigoImageData *imgData1 = (PiwigoImageData*)obj1;
		PiwigoImageData *imgData2 = (PiwigoImageData*)obj2;
		
		return [imgData1.imageId integerValue] < [imgData2.imageId integerValue];
	}];
}

@end
