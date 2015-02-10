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
@property (nonatomic, strong) UIProgressView *uploadProgress;

@property (nonatomic, assign) NSInteger currentImage;
@property (nonatomic, assign) NSInteger maxImages;

@end

@implementation ImageUploadProgressView

+(ImageUploadProgressView*)sharedInstance
{
	static ImageUploadProgressView *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
	});
	return instance;
}

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoWhiteCream];
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.currentImage = 1;
		self.maxImages = 0;
		
		[ImageUploadManager sharedInstance].delegate = self;
		
		self.imageCountLabel = [UILabel new];
		self.imageCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.imageCountLabel.font = [UIFont piwigoFontNormal];
		self.imageCountLabel.textColor = [UIColor piwigoGray];
		self.imageCountLabel.text = @"Uploading 0/0";
		self.imageCountLabel.minimumScaleFactor = 0.5;
		self.imageCountLabel.adjustsFontSizeToFitWidth = YES;
		self.imageCountLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		[self addSubview:self.imageCountLabel];
		[self addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.imageCountLabel]];
		
		self.uploadProgress = [[UIProgressView alloc] init];
		self.uploadProgress.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:self.uploadProgress];
		[self addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.uploadProgress]];
		
		[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label(<=200)]-10-[progress]-15-|"
																	 options:kNilOptions
																	 metrics:nil
																	   views:@{@"label" : self.imageCountLabel,
																			   @"progress" : self.uploadProgress}]];
		
	}
	return self;
}

-(void)addViewToView:(UIView*)view forBottomLayout:(id)bottomLayout
{
	if(view.superview)
	{
		[self removeFromSuperview];
	}
	
	[view addSubview:self];
	[view addConstraints:[NSLayoutConstraint constraintFillWidth:self]];
	[view addConstraint:[NSLayoutConstraint constraintWithItem:self
														  attribute:NSLayoutAttributeBottom
														  relatedBy:NSLayoutRelationEqual
															 toItem:bottomLayout
														  attribute:NSLayoutAttributeTop
														 multiplier:1.0
														   constant:0]];
	[view addConstraint:[NSLayoutConstraint constrainViewToHeight:self height:50]];
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

#pragma mark ImageUploadManagerDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks
{
	CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
	CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
	CGFloat peiceProgress = (CGFloat)current / total;
	CGFloat totalProgress = onChunkPercent + (chunkPercent * peiceProgress);
	if(totalProgress > 1)
	{
		totalProgress = 1;
	}
	[self.uploadProgress setProgress:totalProgress animated:YES];
	
	if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:)])
	{
		[self.delegate imageProgress:image onCurrent:current forTotal:total onChunk:currentChunk forChunks:totalChunks];
	}
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
	self.currentImage = rank;
	if(rank >= totalInQueue)
	{
		self.currentImage = totalInQueue;
	}
	[self updateImageCountLabel];
	[self.uploadProgress setProgress:0 animated:NO];
	
	if(rank == totalInQueue)
	{
		if(self.superview)
		{
			[UIView animateWithDuration:0.8
								  delay:1.0
								options:kNilOptions
							 animations:^{
								 self.alpha = 0;
							 } completion:^(BOOL finished) {
								 [self removeFromSuperview];
							 }];
		}
	}
	
	if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
	{
		[self.delegate imageUploaded:image placeInQueue:rank outOf:totalInQueue withResponse:response];
	}
}

-(void)imagesToUploadChanged:(NSInteger)imagesLeftToUpload
{
	self.maxImages = imagesLeftToUpload;
	[self updateImageCountLabel];
	
	if([self.delegate respondsToSelector:@selector(imagesToUploadChanged:)])
	{
		[self.delegate imagesToUploadChanged:imagesLeftToUpload];
	}
}

@end
