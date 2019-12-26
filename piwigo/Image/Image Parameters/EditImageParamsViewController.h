//
//  EditImageParamsViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PiwigoImageData.h"

@class PiwigoImageData;

@protocol EditImageParamsDelegate <NSObject>

-(void)didDeselectImageToEdit:(NSInteger)imageId;
-(void)didFinishEditingParams:(PiwigoImageData *)params;
-(void)didRenameFileOfImage:(PiwigoImageData *)imageData;

@end

@interface EditImageParamsViewController : UIViewController

@property (nonatomic, weak) id<EditImageParamsDelegate> delegate;
@property (nonatomic, strong) NSArray<PiwigoImageData *> *images;

@end
