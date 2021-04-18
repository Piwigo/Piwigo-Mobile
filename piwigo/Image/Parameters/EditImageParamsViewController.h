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

-(void)didDeselectImageWithId:(NSInteger)imageId;
-(void)didRenameFileOfImage:(PiwigoImageData *)imageData;
-(void)didChangeParamsOfImage:(PiwigoImageData *)params;
-(void)didFinishEditingParameters;

@end

@interface EditImageParamsViewController : UIViewController

@property (nonatomic, weak) id<EditImageParamsDelegate> delegate;
@property (nonatomic, strong) NSArray<PiwigoImageData *> *images;
@property (nonatomic, assign) BOOL hasTagCreationRights;

@end
