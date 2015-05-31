//
//  CategoryMoveToViewController.h
//  piwigo
//
//  Created by Olaf on 21/05/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CategoryListViewController.h"

@interface CategoryMoveToViewController : CategoryListViewController <CategoryListDelegate>

@property (nonatomic, strong) NSArray *selectedImages;

@end
