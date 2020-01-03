//
//  ImageUploadThumbTableViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ImageUpload.h"

FOUNDATION_EXPORT NSString * const kImageUploadThumbTableCell_ID;

@protocol ImageUploadThumbnailCellDelegate <NSObject>

-(void)didDeselectImageWithId:(NSInteger)imageId;

@end

@interface ImageUploadThumbTableViewCell : UITableViewCell

@property (nonatomic, weak) id<ImageUploadThumbnailCellDelegate> delegate;
-(void)setupWithImages:(NSArray<ImageUpload *> *)imageSelection;

@end
