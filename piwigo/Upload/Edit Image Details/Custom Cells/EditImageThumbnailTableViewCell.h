//
//  EditImageThumbnailTableViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "ImageUpload.h"

@interface EditImageThumbnailTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *imageThumbnail;
@property (weak, nonatomic) IBOutlet UILabel *imageDate;
@property (weak, nonatomic) IBOutlet UILabel *imageSize;
@property (weak, nonatomic) IBOutlet UILabel *imageFile;
@property (weak, nonatomic) IBOutlet UILabel *imageTime;
@property (weak, nonatomic) IBOutlet UIButton *editImageButton;

-(void)setupWithImage:(ImageUpload *)imageDetails;
-(IBAction)editImage;

@end
