//
//  ClearCache.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ClearCache.h"
#import "CategoriesData.h"
#import "TagsData.h"

@implementation ClearCache

+(void)clearAllCache
{
	[[TagsData sharedInstance] clearCache];
	[[CategoriesData sharedInstance] clearCache];
}

@end
