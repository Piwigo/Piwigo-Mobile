//
//  ImageService.h
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

FOUNDATION_EXPORT NSString * const kGetImageOrderFileName;
FOUNDATION_EXPORT NSString * const kGetImageOrderId;
FOUNDATION_EXPORT NSString * const kGetImageOrderName;
FOUNDATION_EXPORT NSString * const kGetImageOrderRating;
FOUNDATION_EXPORT NSString * const kGetImageOrderDateCreated;
FOUNDATION_EXPORT NSString * const kGetImageOrderDateAdded;
FOUNDATION_EXPORT NSString * const kGetImageOrderRandom;
FOUNDATION_EXPORT NSString * const kGetImageOrderAscending;
FOUNDATION_EXPORT NSString * const kGetImageOrderDescending;

@class PiwigoImageData;

@interface ImageService : NetworkHandler

+(NSURLSessionTask*)getImagesForAlbumId:(NSInteger)albumId
                                 onPage:(NSInteger)page
                               forOrder:(NSString*)order
                           OnCompletion:(void (^)(NSURLSessionTask *task, NSArray *albumImages))completion
                              onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)getImageInfoById:(NSInteger)imageId
                    ListOnCompletion:(void (^)(NSURLSessionTask *task, PiwigoImageData *imageData))completion
                           onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionTask*)deleteImage:(PiwigoImageData*)image
               ListOnCompletion:(void (^)(NSURLSessionTask *task))completion
                      onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

+(NSURLSessionDownloadTask*)downloadImage:(PiwigoImageData*)image
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler;

+(NSURLSessionTask*)downloadVideo:(PiwigoImageData*)video
                       onProgress:(void (^)(NSProgress *))progress
                completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler;

+(NSURLSessionTask*)loadImageChunkForLastChunkCount:(NSInteger)lastImageBulkCount
                                        forCategory:(NSInteger)categoryId
                                             onPage:(NSInteger)onPage
                                            forSort:(NSString*)sort
                                   ListOnCompletion:(void (^)(NSURLSessionTask *task, NSInteger count))completion
                                          onFailure:(void (^)(NSURLSessionTask *task, NSError *error))fail;

@end
