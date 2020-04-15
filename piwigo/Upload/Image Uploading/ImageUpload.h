//
//  ImageUpload.h
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const kPiwigoNotificationDeselectImageToUpload;

@class PiwigoImageData;
@class PHAsset;

@interface ImageUpload : NSObject

@property (nonatomic, strong) PHAsset *imageAsset;              // Local image
@property (nonatomic, strong) NSString *thumbnailUrl;           // Piwigo image
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *imageTitle;             // Don't use title!
@property (nonatomic, assign) NSInteger categoryToUploadTo;
@property (nonatomic, assign) NSInteger privacyLevel;
@property (nonatomic, strong) NSString *author;
@property (nonatomic, strong) NSString *comment;                // Don't use description
@property (nonatomic, strong) NSArray *tags;
@property (nonatomic, assign) NSInteger imageId;
@property (nonatomic, assign) NSInteger pixelWidth;
@property (nonatomic, assign) NSInteger pixelHeight;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, assign) BOOL stopUpload;

-(instancetype)initWithImageAsset:(PHAsset*)imageAsset forCategory:(NSInteger)category
                     privacyLevel:(NSInteger)privacy author:(NSString*)author;

@end
