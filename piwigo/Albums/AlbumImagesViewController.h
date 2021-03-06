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

FOUNDATION_EXPORT NSString * const kPiwigoNotificationDidShareImage;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCancelDownloadImage;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationDidShareVideo;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationCancelDownloadVideo;

@interface AlbumImagesViewController : UIViewController

@property (nonatomic, assign) NSInteger categoryId;

-(instancetype)initWithAlbumId:(NSInteger)albumId inCache:(BOOL)isCached;

@end
