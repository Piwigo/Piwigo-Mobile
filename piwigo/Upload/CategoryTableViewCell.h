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

@property (weak, nonatomic) IBOutlet UILabel *categoryLabel;
@property (weak, nonatomic) IBOutlet UILabel *subAlbumsLabel;
@property (weak, nonatomic) IBOutlet UIImageView *upDownImage;
@property (nonatomic, strong) IBOutlet UIView *loadTapView;

-(void)tappedLoadView;
-(void)setupWithCategoryData:(PiwigoAlbumData*)category;
-(void)setupDefaultCellWithCategoryData:(PiwigoAlbumData*)category;

@end
