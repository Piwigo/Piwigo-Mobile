//
//  ImageUploadTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/5/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kImageUploadCell_ID;

@class ImageUpload;

@interface ImageUploadTableViewCell : MGSwipeTableCell

@property (nonatomic, assign) BOOL isInQueueForUpload;
@property (nonatomic, assign) CGFloat imageProgress;
@property (nonatomic, strong) ImageUpload *imageUploadInfo;

-(void)setupWithImageInfo:(ImageUpload*)imageInfo;

@end
