//
//  AlbumService.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

@class PiwigoImageData;

@interface AlbumService : NetworkHandler

+(AFHTTPRequestOperation*)getAlbumListOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSArray *albums))completion
										 onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

@end
