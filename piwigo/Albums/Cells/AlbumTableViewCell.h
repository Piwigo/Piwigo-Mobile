//
//  AlbumTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kAlbumTableCell_ID;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationDeletedCategory;

@protocol AlbumTableViewCellDelegate <NSObject>

-(void)pushView:(UIViewController*)viewController;

@end

@class PiwigoAlbumData;

@interface AlbumTableViewCell : MGSwipeTableCell

@property (nonatomic, weak) id<AlbumTableViewCellDelegate> cellDelegate;
@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;
@property (weak, nonatomic) IBOutlet UIButton *topCut;
@property (weak, nonatomic) IBOutlet UIButton *bottomCut;
@property (weak, nonatomic) IBOutlet UILabel *albumName;
@property (weak, nonatomic) IBOutlet UILabel *albumComment;
@property (weak, nonatomic) IBOutlet UILabel *numberOfImages;
@property (weak, nonatomic) IBOutlet UIButton *handleButton;

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;

@end
