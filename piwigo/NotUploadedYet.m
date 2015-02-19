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

@implementation NotUploadedYet

+(void)getListOfImageNamesThatArentUploadedForCategory:(NSInteger)categoryId onCompletion:(void (^)(NSArray *missingImages))completion
{
	[[[CategoriesData sharedInstance] getCategoryById:categoryId] loadAllCategoryImageDataOnCompletion:^(BOOL completed) {
		NSArray *onlineImageData = [[CategoriesData sharedInstance] getCategoryById:categoryId].imageList;
		
		NSMutableDictionary *onlineImageNamesLookup = [NSMutableDictionary new];
		for(PiwigoImageData *imgData in onlineImageData)
		{
			[onlineImageNamesLookup setObject:imgData.fileName forKey:imgData.fileName];
		}
		
		NSMutableArray *localImageNamesThatNeedToBeUploaded = [NSMutableArray new];
		
		for(NSString *imageKey in [PhotosFetch sharedInstance].localImages)
		{
			if(![onlineImageNamesLookup objectForKey:imageKey])
			{	// this image doesn't exist in this online category
				[localImageNamesThatNeedToBeUploaded addObject:imageKey];
			}
		}
		
		if(completion)
		{
			completion(localImageNamesThatNeedToBeUploaded);
		}
		
	}];
}

@end
