//
//  NotUploadedYet.m
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NotUploadedYet.h"
#import "CategoriesData.h"
#import "PiwigoAlbumData.h"
#import "PhotosFetch.h"
#import <AssetsLibrary/AssetsLibrary.h>

@implementation NotUploadedYet

+(void)getListOfImageNamesThatArentUploadedForCategory:(NSInteger)categoryId
											withImages:(NSArray*)images
										   forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
										  onCompletion:(void (^)(NSArray *missingImages))completion
{
	[[[CategoriesData sharedInstance] getCategoryById:categoryId] loadAllCategoryImageDataForProgress:progress
																						 OnCompletion:^(BOOL completed) {
		NSArray *onlineImageData = [[CategoriesData sharedInstance] getCategoryById:categoryId].imageList;
		
		NSMutableDictionary *onlineImageNamesLookup = [NSMutableDictionary new];
		for(PiwigoImageData *imgData in onlineImageData)
		{
            if (imgData.fileName && [imgData.fileName length]) {
                [onlineImageNamesLookup setObject:imgData.fileName forKey:imgData.fileName];
            }
		}
		
		NSMutableArray *localImageNamesThatNeedToBeUploaded = [NSMutableArray new];

		for(ALAsset *imageAsset in images)
		{
			NSString *imageAssetKey = [[imageAsset defaultRepresentation] filename];
			if(imageAssetKey && ![imageAssetKey isEqualToString:@""] && ![onlineImageNamesLookup objectForKey:imageAssetKey])
			{	// this image doesn't exist in this online category
				[localImageNamesThatNeedToBeUploaded addObject:imageAsset];
			}
		}
		
		if(completion)
		{
			completion(localImageNamesThatNeedToBeUploaded);
		}
		
	}];
}

@end
