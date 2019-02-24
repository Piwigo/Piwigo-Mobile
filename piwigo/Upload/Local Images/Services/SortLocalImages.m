//
//  SortLocalImages.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/02/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>

#import "NotUploadedYet.h"
#import "SortLocalImages.h"

@implementation SortLocalImages

+(NSString*)getNameForSortType:(kPiwigoSortBy)sortType
{
    NSString *name = @"";
    
    switch(sortType)
    {
        case kPiwigoSortByNewest:
            name = NSLocalizedString(@"categorySort_dateCreatedDescending", @"Date Created, new → old");
            break;
        case kPiwigoSortByOldest:
            name = NSLocalizedString(@"categorySort_dateCreatedAscending", @"Date Created, old → new");
            break;
        case kPiwigoSortByNotUploaded:
            name = NSLocalizedString(@"localImageSort_notUploaded", @"Not Uploaded");
            break;
            
        default:
            name = NSLocalizedString(@"localImageSort_undefined", @"Undefined");
            break;
    }
    
    return name;
}

// on completion send back a list of image names (keys)
+(void)getSortedImageArrayFromSortType:(kPiwigoSortBy)sortType
                             forImages:(NSArray*)images
                           forCategory:(NSInteger)category
                           forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                          onCompletion:(void (^)(NSArray *images))completion
{
    switch(sortType)
    {
        case kPiwigoSortByNewest:
        {
            [self organizeImages:images byNewestFirstOnCompletion:completion];
            break;
        }
        case kPiwigoSortByOldest:
        {
            [self organizeImages:images byOldestFirstOnCompletion:completion];
            break;
        }
        case kPiwigoSortByNotUploaded:
        {
            [self getNotUploadedImageListForCategory:category withImages:images forProgress:progress onCompletion:completion];
            break;
        }
            
        default:
        {
            if(completion)
            {
                completion(nil);
            }
        }
    }
}

+(void)organizeImages:(NSArray*)images byNewestFirstOnCompletion:(void (^)(NSArray *images))completion
{
    NSArray *sortedImages = [images sortedArrayUsingComparator:^NSComparisonResult(PHAsset *obj1, PHAsset *obj2) {
        return [obj1.creationDate compare:obj2.creationDate] != NSOrderedDescending;
    }];
    
    if(completion)
    {
        completion(sortedImages);
    }
}

+(void)organizeImages:(NSArray*)images byOldestFirstOnCompletion:(void (^)(NSArray *images))completion
{
    NSArray *sortedImages = [images sortedArrayUsingComparator:^NSComparisonResult(PHAsset *obj1, PHAsset *obj2) {
        return [obj1.creationDate compare:obj2.creationDate] != NSOrderedAscending;
    }];
    
    if(completion)
    {
        completion(sortedImages);
    }
}

+(void)getNotUploadedImageListForCategory:(NSInteger)category
                               withImages:(NSArray*)images
                              forProgress:(void (^)(NSInteger onPage, NSInteger outOf))progress
                             onCompletion:(void (^)(NSArray *imageNames))completion
{
    [NotUploadedYet getListOfImageNamesThatArentUploadedForCategory:category
                                                         withImages:images
                                                        forProgress:progress
                                                       onCompletion:completion];
}

@end
