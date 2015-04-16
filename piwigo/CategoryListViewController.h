//
//  CategoryListViewController.h
//  piwigo
//
//  Created by Spencer Baker on 4/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoAlbumData;

@protocol CategoryListDelegate <NSObject>

-(void)selectedCategory:(PiwigoAlbumData*)category;

@end


@interface CategoryListViewController : UIViewController

@property (nonatomic, strong) NSMutableArray *categories;
@property (nonatomic, weak) id<CategoryListDelegate> categoryListDelegate;

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

@end
