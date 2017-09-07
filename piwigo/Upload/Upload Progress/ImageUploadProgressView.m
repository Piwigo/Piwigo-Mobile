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
@property (nonatomic, assign) NSInteger totalUploadedImages;

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
		self.totalUploadedImages = 0;
		
		[ImageUploadManager sharedInstance].delegate = self;
		
		self.imageCountLabel = [UILabel new];
		self.imageCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.imageCountLabel.font = [UIFont piwigoFontNormal];
		self.imageCountLabel.textColor = [UIColor piwigoGray];
		self.imageCountLabel.text = NSLocalizedString(@"imageUploadProgressBar_zero", @"Uploading 0/0");
		self.imageCountLabel.minimumScaleFactor = 0.5;
		self.imageCountLabel.adjustsFontSizeToFitWidth = YES;
		self.imageCountLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		[self addSubview:self.imageCountLabel];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.imageCountLabel]];
		
		self.uploadProgress = [[UIProgressView alloc] init];
		self.uploadProgress.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:self.uploadProgress];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.uploadProgress]];
		
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
														  attribute:NSLayoutAttributeBottom
														 multiplier:1.0
														   constant:0]];
	[view addConstraint:[NSLayoutConstraint constraintView:self toHeight:50]];
}

-(void)updateImageCountLabel
{
	if(self.maxImages == 0)
	{
		self.imageCountLabel.text = NSLocalizedString(@"imageUploadProgressBar_completed", @"Completed");
	}
	else
	{
		self.imageCountLabel.text = [NSString stringWithFormat:NSLocalizedString(@"imageUploadProgressBar_nonZero", @"Uploading %@/%@"), @(self.currentImage), @(self.maxImages)];
	}
}

#pragma mark ImageUploadManagerDelegate Methods

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks
{
	CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
	CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
	CGFloat peiceProgress = (CGFloat)current / total;
	CGFloat totalProgressForThisImage = (onChunkPercent + (chunkPercent * peiceProgress)) / self.maxImages;
	CGFloat totalBatchProgress = (self.totalUploadedImages / (CGFloat)self.maxImages) + totalProgressForThisImage;
	
	[self.uploadProgress setProgress:totalBatchProgress animated:YES];
	
	if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:)])
	{
		[self.delegate imageProgress:image onCurrent:current forTotal:total onChunk:currentChunk forChunks:totalChunks];
	}
}

-(void)imageUploaded:(ImageUpload *)image placeInQueue:(NSInteger)rank outOf:(NSInteger)totalInQueue withResponse:(NSDictionary *)response
{
    // Increment the number of downloaded media only if upload succeeded
    if(!(response == nil)) {
        self.totalUploadedImages++;
    }
	
	self.currentImage = rank;
	if(rank >= totalInQueue)
	{
		self.currentImage = totalInQueue;
	}
	[self updateImageCountLabel];
	
	if(rank > totalInQueue)
	{
		[self.uploadProgress setProgress:0 animated:NO];
        
        // Inform user that the upload task completed
        [UIAlertView showWithTitle:NSLocalizedString(@"imageUploadCompleted_title", @"Upload Completed")
                           message:(self.totalUploadedImages > 1) ? [NSString stringWithFormat:@"%ld %@", (long)self.totalUploadedImages, NSLocalizedString(@"imageUploadCompleted_message>1", @"images/videos uploaded to your Piwigo server.")]: NSLocalizedString(@"imageUploadCompleted_message", @"1 image/video uploaded to your Piwigo server.")
                 cancelButtonTitle:NSLocalizedString(@"alertOkButton", @"OK")
                 otherButtonTitles:nil
                          tapBlock:nil];
        
        // Tnitialise the counters for the next upload taks
		self.totalUploadedImages = 0;
        self.currentImage = 1;
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
