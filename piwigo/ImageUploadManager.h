//
//  ImageUploadManager.h
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UploadService.h"
#import "Model.h"

@class ImageUpload;

typedef enum {
	kImagePermissionEverybody = 0,
	kImagePermissionAdminsFamilyFriendsContacts = 1,
	kImagePermissionAdminsFamilyFriends = 2,
	kImagePermissionAdminsFamily = 4,
	kImagePermissionAdmins = 8,
} kImagePermission;

@protocol ImageUploadDelegate <NSObject>

-(void)imageUploaded:(ImageUpload*)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary*)response;
-(void)imageProgress:(ImageUpload*)image onCurrent:(NSInteger)current forTotal:(NSInteger)total  onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks;

@optional
-(void)imagesToUploadChanged:(NSInteger)imagesLeftToUpload;

@end

@interface ImageUploadManager : UploadService

+(ImageUploadManager*)sharedInstance;

@property (nonatomic, strong) NSMutableArray *imageUploadQueue;
@property (nonatomic, strong) NSMutableDictionary *imageNamesUploadQueue;
@property (nonatomic, readonly) NSInteger maximumImagesForBatch;
@property (nonatomic, weak) id<ImageUploadDelegate> delegate;

-(void)addImage:(NSString*)imageName forCategory:(NSInteger)category andPrivacy:(kPiwigoPrivacy)privacy;
-(void)addImages:(NSArray*)imageNames forCategory:(NSInteger)category andPrivacy:(kPiwigoPrivacy)privacy;
-(void)addImage:(ImageUpload*)image;
-(void)addImages:(NSArray*)images;

-(NSInteger)getIndexOfImage:(ImageUpload*)image;

@end
