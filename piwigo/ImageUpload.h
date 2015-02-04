//
//  ImageUpload.h
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ImageUpload : NSObject

@property (nonatomic, strong) NSString *imageUploadName;
@property (nonatomic, assign) NSInteger categoryToUploadTo;
@property (nonatomic, assign) NSInteger privacyLevel;

-(instancetype)initWithImageName:(NSString*)imageName forCategory:(NSInteger)category forPrivacyLevel:(NSInteger)privacy;

@end
