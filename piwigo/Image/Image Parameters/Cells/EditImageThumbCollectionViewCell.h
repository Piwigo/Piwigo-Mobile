//
//  EditImageThumbCollectionViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

FOUNDATION_EXPORT NSString * const kEditImageThumbCollectionCell_ID;

@protocol EditImageThumbnailDelegate <NSObject>

-(void)didDeselectImageWithId:(NSInteger)imageId;
-(void)didRenameFileOfImageWithId:(NSInteger)imageId andFilename:(NSString *)fileName;

@end

@interface EditImageThumbCollectionViewCell : UICollectionViewCell

@property (nonatomic, assign) NSInteger imageId;
@property (nonatomic, weak) id<EditImageThumbnailDelegate> delegate;

-(void)setupWithImage:(PiwigoImageData *)imageData removeOption:(BOOL)hasRemove andWidth:(CGFloat)width;
-(IBAction)editFileName;
-(IBAction)removeImage;

@end
