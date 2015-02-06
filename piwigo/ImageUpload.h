//
//  ImageUpload.h
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ImageUpload : NSObject

@property (nonatomic, strong) NSString *image;
@property (nonatomic, strong) NSString *imageUploadName;
@property (nonatomic, assign) NSInteger categoryToUploadTo;
@property (nonatomic, assign) NSInteger privacyLevel;
@property (nonatomic, strong) NSString *author;
@property (nonatomic, strong) NSString *imageDescription;
@property (nonatomic, strong) NSString *tags;

-(instancetype)initWithImageName:(NSString*)imageName forCategory:(NSInteger)category forPrivacyLevel:(NSInteger)privacy;
-(instancetype)initWithImageName:(NSString*)imageName forCategory:(NSInteger)category forPrivacyLevel:(NSInteger)privacy author:(NSString*)author description:(NSString*)description andTags:(NSString*)tags;

@end
