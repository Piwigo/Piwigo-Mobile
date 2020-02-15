//
//  ClearCache.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoriesData.h"
#import "LocationsData.h"
#import "TagsData.h"

@implementation ClearCache

+(void)clearAllCache
{
	// Data
    [[TagsData sharedInstance] clearCache];
	[[CategoriesData sharedInstance] clearCache];
    
    // URL requests
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // Place names
    [[LocationsData sharedInstance] clearCache];
}

@end
