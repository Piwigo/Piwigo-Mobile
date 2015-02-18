//
//  TagsService.h
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "NetworkHandler.h"

@interface TagsService : NetworkHandler

+(AFHTTPRequestOperation*)getTagsOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
									onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail;

@end
