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
#import "SplitLocalImages.h"

@implementation NotUploadedYet

+(void)getListOfImageNamesThatArentUploadedForCategory:(NSInteger)categoryId
                                            withImages:(NSArray*)imagesInSections
                                           forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                                          onCompletion:(void (^)(NSArray *imagesNotUploaded))completion
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
                 
                 // Don't forget to replace the extension of video files (.mov in iOS device, .mp4 in Piwigo server)
                 if([[[imgData.fileName pathExtension] uppercaseString] isEqualToString:@"MP4"])
                 {
                     // Replace file extension
                     imgData.fileName = [[imgData.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"MOV"];
                 }
                 // Append to list of Piwigo images
                 [onlineImageNamesLookup setObject:imgData.fileName forKey:imgData.fileName];
             }
         }
         
         // Collect list of local images
         NSMutableArray *localImagesThatNeedToBeUploaded = [NSMutableArray new];
         
         // Build list of images which have not already been uploaded to the Piwigo server
         for (NSArray *imagesInSection in imagesInSections) {

             // Loop over images of section
             for (PHAsset *imageAsset in imagesInSection) {
                 
                 // For some unknown reason, the asset resource may be empty
                 NSArray *resources = [PHAssetResource assetResourcesForAsset:imageAsset];
                 NSString *imageAssetKey;
                 if ([resources count] > 0) {
                     // File name is available
                     imageAssetKey = ((PHAssetResource*)resources[0]).originalFilename;
                     
                     // HEIC images were converted to JPEG if uploaded
                     if ([[[imageAssetKey pathExtension] uppercaseString] isEqualToString:@"HEIC"])
                     {
                         // Replace file extension
                         imageAssetKey = [[imageAssetKey stringByDeletingPathExtension] stringByAppendingPathExtension:@"JPG"];
                     }
                 } else {
                     // No filename => Build filename from 32 characters of local identifier
                     NSRange range = [imageAsset.localIdentifier rangeOfString:@"/"];
                     imageAssetKey = [[imageAsset.localIdentifier substringToIndex:range.location] stringByReplacingOccurrencesOfString:@"-" withString:@""];
                     
                     // Filename extension required by Piwigo so that it knows how to deal with it
                     if (imageAsset.mediaType == PHAssetMediaTypeImage) {
                         // Adopt JPEG photo format by default, will be rechecked
                         imageAssetKey = [imageAssetKey stringByAppendingPathExtension:@"JPG"];
                     } else if (imageAsset.mediaType == PHAssetMediaTypeVideo) {
                         // Videos are exported in MP4 format
                         imageAssetKey = [imageAssetKey stringByAppendingPathExtension:@"MP4"];
                     } else if (imageAsset.mediaType == PHAssetMediaTypeAudio) {
                         // Arbitrary extension, not managed yet
                         imageAssetKey = [imageAssetKey stringByAppendingPathExtension:@"M4A"];
                     }
                 }
                 
                 // Compare filenames of local and remote images
                 if(imageAssetKey && ![imageAssetKey isEqualToString:@""] && ![onlineImageNamesLookup objectForKey:imageAssetKey])
                 {    // This image doesn't exist in this online category
                     [localImagesThatNeedToBeUploaded addObject:imageAsset];
                 }
             }
         }
         
         // Sort images by day
         NSArray *imagesByDate = [NSMutableArray new];
         imagesByDate = [SplitLocalImages splitImagesByDate:localImagesThatNeedToBeUploaded];
         
         if(completion)
         {
             completion(imagesByDate);
         }
     }];
}

@end
