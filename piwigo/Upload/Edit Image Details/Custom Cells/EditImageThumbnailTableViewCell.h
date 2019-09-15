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

//-(void)applyColorPalette;
-(void)setupWithImage:(ImageUpload *)imageDetails;

@end
