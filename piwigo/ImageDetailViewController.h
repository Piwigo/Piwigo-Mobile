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
-(void)needToLoadMoreImages;

@end

@class PiwigoImageData;

@interface ImageDetailViewController : UIPageViewController

@property (nonatomic, weak) id<ImageDetailDelegate> imgDetailDelegate;

-(instancetype)initWithCategoryId:(NSInteger)categoryId atImageIndex:(NSInteger)imageIndex isSorted:(BOOL)isSorted withArray:(NSArray*)array;

@end
