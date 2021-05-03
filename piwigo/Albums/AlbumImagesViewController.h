//
//  AlbumImagesViewController.h
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kPiwigoNotificationBackToDefaultAlbum;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationLeftUploads;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationUploadProgress;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationUploadedImage;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationDeletedImage;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationChangedAlbumData;

FOUNDATION_EXPORT NSString * const kPiwigoNotificationDidShare;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCancelDownload;

@interface AlbumImagesViewController : UIViewController

@property (nonatomic, assign) NSInteger categoryId;

-(instancetype)initWithAlbumId:(NSInteger)albumId inCache:(BOOL)isCached;

@end
