//
//  CategoryTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 3/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoAlbumData;

@protocol CategoryCellDelegate <NSObject>

-(void)tappedDisclosure:(PiwigoAlbumData*)categoryTapped;

@end

@interface CategoryTableViewCell : UITableViewCell

@property (nonatomic, weak) id<CategoryCellDelegate> categoryDelegate;
@property (nonatomic, assign) BOOL hasLoadedSubCategories;

-(void)setupWithCategoryData:(PiwigoAlbumData*)category;
-(void)setCellLeftLabel:(NSString*)text;

@end
