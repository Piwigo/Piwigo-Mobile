//
//  ImageDetailViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PiwigoImageData;

@interface ImageDetailViewController : UIViewController

-(instancetype)initWithCategoryId:(NSString*)categoryId andImageIndex:(NSInteger)imageIndex;
-(void)setupWithImageData:(PiwigoImageData*)imageData andPlaceHolderImage:(UIImage*)placeHolder;

@end
