//
//  AlbumService.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
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

@interface AlbumService : NetworkHandler

+(AFHTTPRequestOperation*)getAlbumListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albums))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

+(AFHTTPRequestOperation*)getAlbumPhotosForAlbumId:(NSInteger)albumId
											onPage:(NSInteger)page
										  forOrder:(NSString*)order
									  OnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albumImages))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;
@end
