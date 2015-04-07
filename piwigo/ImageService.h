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

+(AFHTTPRequestOperation*)getImagesForAlbumId:(NSInteger)albumId
											onPage:(NSInteger)page
										  forOrder:(NSString*)order
									  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albumImages))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)getImageInfoById:(NSInteger)imageId
						  ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, PiwigoImageData *imageData))completion
								 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)deleteImage:(PiwigoImageData*)image
						 ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation))completion
								onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)downloadImage:(PiwigoImageData*)image
							 onProgress:(void (^)(NSInteger current, NSInteger total))progress
					   ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, UIImage *image))completion
							  onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;
+(AFHTTPRequestOperation*)downloadVideo:(PiwigoImageData*)video
							 onProgress:(void (^)(NSInteger current, NSInteger total))progress
					   ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, id response))completion
							  onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)loadImageChunkForLastChunkCount:(NSInteger)lastImageBulkCount
											  forCategory:(NSInteger)categoryId
												   onPage:(NSInteger)onPage
												  forSort:(NSString*)sort
										 ListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSInteger count))completion
												onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

@end
