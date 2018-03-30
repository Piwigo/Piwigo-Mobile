//
//  ImageUploadProgressView.h
//  piwigo
//
//  Created by Spencer Baker on 2/4/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageUpload;

@protocol ImageUploadProgressDelegate <NSObject>

-(void)imageUploaded:(ImageUpload*)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary*)response;
-(void)imageProgress:(ImageUpload*)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks iCloudProgress:(CGFloat)progress;

@optional
-(void)imagesToUploadChanged:(NSInteger)imagesLeftToUpload;

@end

@interface ImageUploadProgressView : UIView

+(ImageUploadProgressView*)sharedInstance;
@property (nonatomic, weak) id<ImageUploadProgressDelegate> delegate;

-(void)addViewToView:(UIView*)view forBottomLayout:(id)bottomLayout;
-(void)changePaletteMode;

@end
