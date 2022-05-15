//
//  AlbumImagesViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageCollectionViewCell;

FOUNDATION_EXPORT NSString * const kPiwigoNotificationBackToDefaultAlbum;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationDidShare;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCancelDownload;

@interface AlbumImagesViewController : UIViewController

@property (nonatomic, assign) NSInteger categoryId;

// See https://medium.com/@tungfam/custom-uiviewcontroller-transitions-in-swift-d1677e5aa0bf
//@property (nonatomic, strong) ImageCollectionViewCell *selectedCell;    // Cell that was selected
//@property (nonatomic, strong) UIView *selectedCellImageViewSnapshot;    // Snapshot of the image view
//@property (nonatomic, strong) ImageAnimatedTransitioning *animator;     // Image cell animator

-(instancetype)initWithAlbumId:(NSInteger)albumId;
-(void)checkDataSourceWithChangedCategories:(BOOL)didChange onCompletion:(void (^)(void))completion;
-(void)updateSubCategoryWithId:(NSInteger)albumId;
-(void)addImageWithId:(NSInteger)imageId;
-(void)removeImageWithId:(NSInteger)imageId;

@end
