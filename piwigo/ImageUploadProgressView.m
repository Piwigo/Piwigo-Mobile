//
//  ImageUploadProgressView.m
//  piwigo
//
//  Created by Spencer Baker on 2/4/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUploadProgressView.h"
#import "ImageUpload.h"
#import "ImageUploadManager.h"

@interface ImageUploadProgressView() <ImageUploadDelegate>

@property (nonatomic, strong) UILabel *imageCountLabel;

@property (nonatomic, assign) NSInteger currentImage;
@property (nonatomic, assign) NSInteger maxImages;
@end

@implementation ImageUploadProgressView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoWhiteCream];
		self.currentImage = 1;
		self.maxImages = 0;
		
		[ImageUploadManager sharedInstance].delegate = self;
		
		self.imageCountLabel = [UILabel new];
		self.imageCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.imageCountLabel.font = [UIFont piwigoFontNormal];
		self.imageCountLabel.textColor = [UIColor piwigoGray];
		self.imageCountLabel.text = @"Uploading 0/0";
		[self addSubview:self.imageCountLabel];
		[self addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.imageCountLabel]];
		[self addConstraint:[NSLayoutConstraint constrainViewFromLeft:self.imageCountLabel amount:15]];
		
	}
	return self;
}

#pragma mark ImageUploadManagerDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks
{
	
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue
{
	self.currentImage = rank;
	if(rank >= totalInQueue)
	{
		self.currentImage = totalInQueue;
	}
	[self updateImageCountLabel];
}

-(void)imagesToUploadChanged:(NSInteger)imagesLeftToUpload
{
	self.maxImages = imagesLeftToUpload;
	[self updateImageCountLabel];
}

-(void)updateImageCountLabel
{
	if(self.maxImages == 0)
	{
		self.imageCountLabel.text = @"Completed";
	}
	else
	{
		self.imageCountLabel.text = [NSString stringWithFormat:@"Uploading %@/%@", @(self.currentImage), @(self.maxImages)];
	}
}

@end
