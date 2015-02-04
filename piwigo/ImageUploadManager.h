//
//  ImageUploadManager.h
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadService.h"

@interface ImageUploadManager : UploadService

+(ImageUploadManager*)sharedInstance;

@property (nonatomic, strong) NSMutableArray *imageUploadQueue;

-(void)addImage:(NSString*)imageName forCategory:(NSInteger)category andPrivacy:(NSInteger)privacy;
-(void)addImages:(NSArray*)imageNames forCategory:(NSInteger)category andPrivacy:(NSInteger)privacy;

@end
