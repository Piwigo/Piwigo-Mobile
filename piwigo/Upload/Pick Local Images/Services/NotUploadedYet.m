//
//  NotUploadedYet.m
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

#import "CategoriesData.h"
#import "NotUploadedYet.h"
#import "PiwigoAlbumData.h"
#import "PhotosFetch.h"

@implementation NotUploadedYet

+(void)getListOfImageNamesThatArentUploadedForCategory:(NSInteger)categoryId
                                            withImages:(NSArray *)imagesInSections
                                         andSelections:(NSArray *)selectedSections
                                           forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                                          onCompletion:(void (^)(NSArray *imagesNotUploaded, NSIndexSet *sectionsToDelete))completion
{
    [[[CategoriesData sharedInstance] getCategoryById:categoryId]
     loadAllCategoryImageDataForProgress:progress
     OnCompletion:^(BOOL completed) {
         
         // Collect list of Piwigo images
         NSArray *onlineImageData = [[CategoriesData sharedInstance] getCategoryById:categoryId].imageList;
         
         // Build list of images on Piwigo server
         NSMutableDictionary *onlineImageNamesLookup = [NSMutableDictionary new];
         for(PiwigoImageData *imgData in onlineImageData)
         {
             // Filename must not be empty!
             if (imgData.fileName && [imgData.fileName length]) {
                 
                 // Don't forget that files can be converted (e.g. .mov in iOS device, .mp4 in Piwigo server)
                 imgData.fileName = [imgData.fileName stringByDeletingPathExtension];
                 
                 // Append to list of Piwigo images
                 [onlineImageNamesLookup setObject:imgData.fileName forKey:imgData.fileName];
             }
         }
         
         // Collect list of local images
         NSMutableIndexSet *sectionsToDelete = [NSMutableIndexSet new];
         NSMutableArray *localImagesThatNeedToBeUploaded = [NSMutableArray new];
         if (imagesInSections.count != selectedSections.count) {
             if(completion)
             {
                 completion(imagesInSections, sectionsToDelete);
             }
             return;
         }
         
         // Build list of images which have not already been uploaded to the Piwigo server
         for (NSInteger index = 0; index < imagesInSections.count; index++) {

             // Images in section
             NSArray *imagesInSection = [imagesInSections objectAtIndex:index];
             
             // Loop over images of section
             NSMutableArray *images = [NSMutableArray new];
             for (PHAsset *imageAsset in imagesInSection) {
                 
                 // Get filename of image asset
                 NSString *imageAssetKey = [[PhotosFetch sharedInstance] getFileNameFomImageAsset:imageAsset];

                 // Don't forget that files can be converted (e.g. .mov in iOS device, .mp4 in Piwigo server)
                 imageAssetKey = [imageAssetKey stringByDeletingPathExtension];
                 
                 // Compare filenames of local and remote images
                 if(imageAssetKey && ![imageAssetKey isEqualToString:@""] && ![onlineImageNamesLookup objectForKey:imageAssetKey])
                 {    // This image doesn't exist in this online category
                     [images addObject:imageAsset];
                 }
             }
             
             // Add section if not empty
             if (images.count) {
                 [localImagesThatNeedToBeUploaded addObject:images];
             } else {
                 [sectionsToDelete addIndex:index];
             }
         }
         
         if(completion)
         {
             completion(localImagesThatNeedToBeUploaded, sectionsToDelete);
         }
     }];
}

@end
