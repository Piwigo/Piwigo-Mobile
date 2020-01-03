//
//  ImageUploadThumbCollectionViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "ImageUpload.h"

FOUNDATION_EXPORT NSString * const kImageUploadThumbCollectionCell_ID;

@protocol ImageUploadThumbnailDelegate <NSObject>

-(void)didDeselectImageWithId:(NSInteger)imageId;

@end

@interface ImageUploadThumbCollectionViewCell : UICollectionViewCell

@property (nonatomic, assign) NSInteger imageId;
@property (nonatomic, weak) id<ImageUploadThumbnailDelegate> delegate;

-(void)setupWithImage:(ImageUpload *)imageDetails andRemoveOption:(BOOL)hasRemove;
-(IBAction)removeImage;

@end
