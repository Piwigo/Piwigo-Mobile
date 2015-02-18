//
//  TagsService.m
//  piwigo
//
//  Created by Spencer Baker on 2/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TagsService.h"

@implementation TagsService

+(AFHTTPRequestOperation*)getTagsOnCompletion:(void (^)(AFHTTPRequestOperation *operation, NSDictionary *response))completion
									onFailure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))fail
{
	return [self post:kPiwigoTagsGetList
		URLParameters:nil
		   parameters:nil
			  success:completion
			  failure:fail];
}

@end
