//
//  AllCategoriesViewController.h
//  piwigo
//
//  Created by Spencer Baker on 3/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CategoryListViewController.h"

@interface AllCategoriesViewController : CategoryListViewController

-(instancetype)initForImageId:(NSInteger)imageId andCategoryId:(NSInteger)categoryId;

@end
