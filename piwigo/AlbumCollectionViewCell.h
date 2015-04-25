//
//  AlbumCollectionViewCell.h
//  piwigo
//
//  Created by Olaf on 01.04.15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AlbumCollectionViewCellDelegate <NSObject>

-(void)pushView:(UIViewController*)viewController;

@end

@class PiwigoAlbumData;
@class OutlinedText;

@interface AlbumCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView *backgroundImage;
@property (nonatomic, weak) IBOutlet OutlinedText *albumName;
@property (nonatomic, weak) IBOutlet UILabel *numberOfImages;
@property (nonatomic, weak) IBOutlet UILabel *numberOfSubCategoryImages;
@property (nonatomic, weak) IBOutlet UILabel *date;
@property (nonatomic, strong) IBOutlet UIView *textUnderlay;
@property (nonatomic, weak) IBOutlet UIImageView *cellDisclosure;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *editViewLeftConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *editViewRightConstraint;

@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UIButton *moveButton;
@property (weak, nonatomic) IBOutlet UIButton *renameButton;
@property (weak, nonatomic) IBOutlet UIView *editView;

/**
 kick cell out off editing mode.
 */
-(void)exitFromEditMode;


/**
 place cell into editing mode.
 */
-(void)goIntoEditMode;

+(UINib *)nib;

+(NSString *)cellReuseIdentifier;

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData;
@property (nonatomic, weak) id<AlbumCollectionViewCellDelegate> cellDelegate;
@property (nonatomic, strong) PiwigoAlbumData *albumData;
//@property (nonatomic, readonly) UIImageView *backgroundImage;

-(IBAction)deleteAction:(id)sender;
-(IBAction)moveAction:(id)sender;
-(IBAction)renameAction:(id)sender;


@end
