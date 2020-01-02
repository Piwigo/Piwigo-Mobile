//
//  EditImageThumbTableViewCell.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

FOUNDATION_EXPORT NSString * const kEditImageThumbTableCell_ID;

@protocol EditImageThumbnailCellDelegate <NSObject>

-(void)didDeselectImageWithId:(NSInteger)imageId;
-(void)didRenameFileOfImage:(PiwigoImageData *)imageData;

@end

@interface EditImageThumbTableViewCell : UITableViewCell

@property (nonatomic, weak) id<EditImageThumbnailCellDelegate> delegate;
-(void)setupWithImages:(NSArray<PiwigoImageData *> *)imageSelection;

@end
