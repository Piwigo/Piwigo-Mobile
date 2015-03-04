//
//  CategoryImageSort.h
//  piwigo
//
//  Created by Spencer Baker on 3/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CategorySortViewController.h"

@interface CategoryImageSort : NSObject

+(NSArray*)sortImages:(NSArray*)images forSortOrder:(kPiwigoSortCategory)sortOrder;

@end
