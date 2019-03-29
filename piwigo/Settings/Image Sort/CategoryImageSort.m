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
		case kPiwigoSortCategoryNameAscending:          // Photo title, A → Z
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.name compare:obj2.name] != NSOrderedAscending;
			}];
			break;
		}
		case kPiwigoSortCategoryNameDescending:         // Photo title, Z → A
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.name compare:obj2.name] != NSOrderedDescending;
			}];
			break;
		}
			
        case kPiwigoSortCategoryDateCreatedDescending:  // Date created, new → old
        {
            newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
                return [obj1.dateCreated compare:obj2.dateCreated] != NSOrderedDescending;
            }];
            break;
        }
        case kPiwigoSortCategoryDateCreatedAscending:   // Date created, old → new
        {
            newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
                return [obj1.dateCreated compare:obj2.dateCreated] != NSOrderedAscending;
            }];
            break;
        }
            
        case kPiwigoSortCategoryDatePostedDescending:  // Date posted, new → old
        {
            newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
                return [obj1.datePosted compare:obj2.datePosted] != NSOrderedDescending;
            }];
            break;
        }
		case kPiwigoSortCategoryDatePostedAscending:   // Date posted, old → new
		{
			newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
				return [obj1.datePosted compare:obj2.datePosted] != NSOrderedAscending;
			}];
			break;
		}
            
        case kPiwigoSortCategoryFileNameAscending:      // File name, A → Z
        {
            newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
                return [obj1.fileName compare:obj2.fileName] != NSOrderedAscending;
            }];
            break;
        }
        case kPiwigoSortCategoryFileNameDescending:     // File name, Z → A
        {
            newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
                return [obj1.fileName compare:obj2.fileName] != NSOrderedDescending;
            }];
            break;
        }
        case kPiwigoSortCategoryVisitsDescending:       // Visits, high → low
        {
            newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
                return [@(obj1.visits) compare:@(obj2.visits)] != NSOrderedDescending;
            }];
            break;
        }
        case kPiwigoSortCategoryVisitsAscending:        // Visits, low → high
        {
            newImageList = [images sortedArrayUsingComparator:^NSComparisonResult(PiwigoImageData *obj1, PiwigoImageData *obj2) {
                return [@(obj1.visits) compare:@(obj2.visits)] != NSOrderedAscending;
            }];
        }

// Data not returned by API pwg.categories.getList
//        case kPiwigoSortCategoryRatingScoreDescending:  // Rating score, high → low
//        {
//        }
//        case kPiwigoSortCategoryRatingScoreAscending:   // Rating score, low → high
//        {
//        }
// and level (permissions)

//		case kPiwigoSortCategoryVideoOnly:
//		{
//			NSIndexSet *set = [images indexesOfObjectsPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL *stop) {
//				return obj.isVideo;
//			}];
//			newImageList = [images objectsAtIndexes:set];
//			break;
//		}
//		case kPiwigoSortCategoryImageOnly:
//		{
//			NSIndexSet *set = [images indexesOfObjectsPassingTest:^BOOL(PiwigoImageData *obj, NSUInteger idx, BOOL *stop) {
//				return !obj.isVideo;
//			}];
//			newImageList = [images objectsAtIndexes:set];
//			break;
//		}
			
		case kPiwigoSortCategoryCount:
			break;
	}
	
	return newImageList;
}

@end
