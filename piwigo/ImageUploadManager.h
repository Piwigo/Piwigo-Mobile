//
//  ImageUploadManager.h
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadService.h"

FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploaded;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploading;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploadNameKey;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploadCurrentKey;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploadTotalKey;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploadPercentKey;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploadCurrentChunkKey;
FOUNDATION_EXPORT NSString * const kPiwigoNotificationImageUploadTotalChunksKey;

@interface ImageUploadManager : UploadService

+(ImageUploadManager*)sharedInstance;

@property (nonatomic, strong) NSMutableArray *imageUploadQueue;

-(void)addImage:(NSString*)imageName forCategory:(NSInteger)category andPrivacy:(NSInteger)privacy;
-(void)addImages:(NSArray*)imageNames forCategory:(NSInteger)category andPrivacy:(NSInteger)privacy;

@end
