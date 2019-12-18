//
//  EditImageThumbnailCollectionViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "ImageUpload.h"

@interface EditImageThumbnailCollectionViewCell : UICollectionViewCell

@property (assign, nonatomic) NSInteger imageId;
@property (weak, nonatomic) IBOutlet UIImageView *imageThumbnail;
@property (weak, nonatomic) IBOutlet UIView *imageDetails;
@property (weak, nonatomic) IBOutlet UILabel *imageDate;
@property (weak, nonatomic) IBOutlet UILabel *imageSize;
@property (weak, nonatomic) IBOutlet UILabel *imageFile;
@property (weak, nonatomic) IBOutlet UILabel *imageTime;

@property (weak, nonatomic) IBOutlet UIView *editButtonView;
@property (weak, nonatomic) IBOutlet UIButton *editImageButton;

@property (weak, nonatomic) IBOutlet UIView *removeButtonView;
@property (weak, nonatomic) IBOutlet UIButton *removeImageButton;

-(void)setupWithImage:(ImageUpload *)imageDetails forEdit:(BOOL)isEdit andRemove:(BOOL)withRemoveButton;
-(IBAction)editImage;
-(IBAction)removeImage;

@end
