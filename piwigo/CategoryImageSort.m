//
//  CategoryImageSort.m
//  piwigo
//
//  Created by Spencer Baker on 3/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryImageSort.h"
#import "PiwigoImageData.h"

@implementation CategoryImageSort

+(NSArray*)sortImages:(NSArray*)images forSortOrder:(kPiwigoSortCategory)sortOrder
{
	NSArray *newImageList = [NSArray new];
	
	switch(sortOrder)
	{
		case kPiwigoSortCategoryIdDescending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return obj1.imageId < obj2.imageId;
			}];
			break;
		}
		case kPiwigoSortCategoryIdAscending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return obj1.imageId > obj2.imageId;
			}];
			break;
		}
			
			
		case kPiwigoSortCategoryFileNameAscending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.fileName compare:obj2.fileName] != NSOrderedAscending;
			}];
			break;
		}
		case kPiwigoSortCategoryFileNameDescending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.fileName compare:obj2.fileName] != NSOrderedDescending;
			}];
			break;
		}
			
			
		case kPiwigoSortCategoryNameAscending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.name compare:obj2.name] != NSOrderedAscending;
			}];
			break;
		}
		case kPiwigoSortCategoryNameDescending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.name compare:obj2.name] != NSOrderedDescending;
			}];
			break;
		}
			
			
		case kPiwigoSortCategoryDateCreatedAscending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.dateAvailable compare:obj2.dateAvailable] != NSOrderedAscending;
			}];
			break;
		}
		case kPiwigoSortCategoryDateCreatedDescending:
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.dateAvailable compare:obj2.dateAvailable] != NSOrderedDescending;
			}];
			break;
		}
			
			
		case kPiwigoSortCategoryCount:
			break;
	}
	
	return newImageList;
}

@end
