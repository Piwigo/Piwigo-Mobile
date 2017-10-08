//
//  NotUploadedYet.m
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>

#import "NotUploadedYet.h"
#import "CategoriesData.h"
#import "PiwigoAlbumData.h"
#import "PhotosFetch.h"

@implementation NotUploadedYet

+(void)getListOfImageNamesThatArentUploadedForCategory:(NSInteger)categoryId
											withImages:(NSArray*)images
										   forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
										  onCompletion:(void (^)(NSArray *missingImages))completion
{
	[[[CategoriesData sharedInstance] getCategoryById:categoryId] loadAllCategoryImageDataForProgress:progress
																						 OnCompletion:^(BOOL completed) {

        // Collect list of Piwigo images
        NSArray *onlineImageData = [[CategoriesData sharedInstance] getCategoryById:categoryId].imageList;
		
        NSMutableDictionary *onlineImageNamesLookup = [NSMutableDictionary new];
        for(PiwigoImageData *imgData in onlineImageData)
        {
            // Filename must not be empty!
            if (imgData.fileName && [imgData.fileName length]) {
                
                // Don't forget to replace the extension of video files (.mov in iOS device, .mp4 in Piwigo server)
                if([[[imgData.fileName pathExtension] uppercaseString] isEqualToString:@"MP4"]) {
                    
                    // Replace file extension
                    imgData.fileName = [[imgData.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"MOV"];
                }
                // Append to list of Piwigo images
                [onlineImageNamesLookup setObject:imgData.fileName forKey:imgData.fileName];
            }
        }
		
        // Collect list of local images
		NSMutableArray *localImageNamesThatNeedToBeUploaded = [NSMutableArray new];

		for(ALAsset *imageAsset in images)
		{
			// Compare filenames
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
