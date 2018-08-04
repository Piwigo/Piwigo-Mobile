//
//  MoveImageViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoImageData;

@protocol MoveImageDelegate <NSObject>

-(void)didDeleteImage:(PiwigoImageData*)image;

@end

@interface MoveImageViewController : UIViewController

@property (nonatomic, weak) id<MoveImageDelegate> moveImageDelegate;

-(instancetype)initWithSelectedImage:(PiwigoImageData*)image inCategoryId:(NSInteger)categoryId andCopyOption:(BOOL)copyImage;

@end
