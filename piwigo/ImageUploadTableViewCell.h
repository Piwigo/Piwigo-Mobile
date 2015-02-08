//
//  ImageUploadTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageUpload;

@interface ImageUploadTableViewCell : UITableViewCell

-(void)setupWithImageInfo:(ImageUpload*)imageInfo;

@end
