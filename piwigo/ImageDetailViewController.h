//
//  ImageDetailViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ImageDetailDelegate <NSObject>

-(void)didDeleteImage;

@end

@class PiwigoImageData;

@interface ImageDetailViewController : UIViewController

@property (nonatomic, weak) id<ImageDetailDelegate> delegate;

-(instancetype)initWithCategoryId:(NSInteger)categoryId andImageIndex:(NSInteger)imageIndex;
-(void)setupWithImageData:(PiwigoImageData*)imageData andPlaceHolderImage:(UIImage*)placeHolder;

@end
