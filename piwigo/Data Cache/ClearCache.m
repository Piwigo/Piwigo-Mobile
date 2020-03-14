//
//  ClearCache.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ClearCache.h"
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
    [[Model sharedInstance].imageCache removeAllCachedResponses];
    
    // Place names
    [[LocationsData sharedInstance] clearCache];
}

@end
