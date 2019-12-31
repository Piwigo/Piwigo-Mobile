//
//  EditImageFilenameCollectionViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>
#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

@protocol EditImageFilenameDelegate <NSObject>

-(void)didDeselectImageWithId:(NSInteger)imageId;
-(void)didRenameFileOfImageWithId:(NSInteger)imageId andFilename:(NSString *)fileName;

@end

@interface EditImageFilenameCollectionViewCell : UICollectionViewCell

@property (assign, nonatomic) NSInteger imageId;
@property (nonatomic, weak) id<EditImageFilenameDelegate> delegate;

-(void)setupWithImage:(PiwigoImageData *)imageData andRemoveOption:(BOOL)hasRemove;
-(IBAction)editImage;
-(IBAction)removeImage;

@end
