//
//  MoveImageViewController.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT CGFloat const kMoveImageViewWidth;

@class PiwigoImageData;

@protocol MoveImageDelegate <NSObject>

-(void)didCopyImageInOneOfCategoryIds:(NSMutableArray*)categoryIds;
-(void)didRemoveImage:(PiwigoImageData*)image atIndex:(NSInteger)index;

@end

@protocol MoveImagesDelegate <NSObject>

-(void)cancelMoveImages;
-(void)didRemoveImage:(PiwigoImageData*)image atIndex:(NSInteger)index;
-(void)deselectImages;

@end

@interface MoveImageViewController : UIViewController

@property (nonatomic, weak) id<MoveImageDelegate> moveImageDelegate;
@property (nonatomic, weak) id<MoveImagesDelegate> moveImagesDelegate;

-(instancetype)initWithSelectedImageIds:(NSArray*)imageIds orSingleImageData:(PiwigoImageData *)imageData inCategoryId:(NSInteger)categoryId atIndex:(NSInteger)index andCopyOption:(BOOL)copyImage;

@end
