//
//  CameraRollUploadViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25 March 2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PHAssetCollection;

@interface CameraRollUploadViewController : UIViewController

-(instancetype)initWithCategoryId:(NSInteger)categoryId;

@end
