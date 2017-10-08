//
//  ImageUpload.h
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Model.h"

@class PiwigoImageData;
@class ALAsset;

@interface ImageUpload : NSObject

@property (nonatomic, strong) ALAsset *imageAsset;
@property (nonatomic, strong) NSString *image;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) NSInteger categoryToUploadTo;
@property (nonatomic, assign) kPiwigoPrivacy privacyLevel;
@property (nonatomic, strong) NSString *author;
@property (nonatomic, strong) NSString *imageDescription;
@property (nonatomic, strong) NSArray *tags;
@property (nonatomic, assign) NSInteger imageId;

-(instancetype)initWithImageAsset:(ALAsset*)imageAsset forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy;
-(instancetype)initWithImageAsset:(ALAsset*)imageAsset forCategory:(NSInteger)category forPrivacyLevel:(kPiwigoPrivacy)privacy author:(NSString*)author description:(NSString*)description andTags:(NSArray*)tags;
-(instancetype)initWithImageData:(PiwigoImageData*)imageData;

@end
