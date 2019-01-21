//
//  ImageUploadProgressView.m
//  piwigo
//
//  Created by Spencer Baker on 2/4/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <Photos/Photos.h>

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
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.currentImage = 1;
		self.maxImages = 0;
		self.totalUploadedImages = 0;
		
		[ImageUploadManager sharedInstance].delegate = self;
		
		self.imageCountLabel = [UILabel new];
		self.imageCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.imageCountLabel.font = [UIFont piwigoFontNormal];
		self.imageCountLabel.text = NSLocalizedString(@"imageUploadProgressBar_zero", @"Uploading 0/0");
		self.imageCountLabel.minimumScaleFactor = 0.5;
		self.imageCountLabel.adjustsFontSizeToFitWidth = YES;
		self.imageCountLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
		[self addSubview:self.imageCountLabel];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.imageCountLabel]];
		
		self.uploadProgress = [[UIProgressView alloc] init];
		self.uploadProgress.translatesAutoresizingMaskIntoConstraints = NO;
        self.uploadProgress.progressTintColor = [UIColor piwigoOrange];
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

-(void)changePaletteMode
{
    self.backgroundColor = [UIColor piwigoBackgroundColor];
    self.imageCountLabel.backgroundColor = [UIColor piwigoBackgroundColor];
    self.imageCountLabel.textColor = [UIColor piwigoRightLabelColor];
    self.uploadProgress.backgroundColor = [UIColor piwigoBackgroundColor];
    self.uploadProgress.trackTintColor = [UIColor piwigoLeftLabelColor];
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

-(void)imageProgress:(ImageUpload *)image onCurrent:(NSInteger)current forTotal:(NSInteger)total onChunk:(NSInteger)currentChunk forChunks:(NSInteger)totalChunks iCloudProgress:(CGFloat)iCloudProgress
{
    CGFloat chunkPercent = 100.0 / totalChunks / 100.0;
    CGFloat onChunkPercent = chunkPercent * (currentChunk - 1);
    CGFloat peiceProgress = (CGFloat)current / total;
    CGFloat totalProgressForThisImage;
    if (iCloudProgress < 0) {
        totalProgressForThisImage = (onChunkPercent + (chunkPercent * peiceProgress)) / fmax(1.0, (CGFloat)self.maxImages);
    } else {
        totalProgressForThisImage = (iCloudProgress + onChunkPercent + (chunkPercent * peiceProgress)) / 2.0 / fmax(1.0, (CGFloat)self.maxImages);
    }
    CGFloat totalBatchProgress = (self.totalUploadedImages / fmax(1.0, (CGFloat)self.maxImages)) + totalProgressForThisImage;

    [self.uploadProgress setProgress:totalBatchProgress animated:YES];
//    NSLog(@"ImageUploadProgressView[imageProgress]: %.2f", totalBatchProgress);

	if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
	{
        [self.delegate imageProgress:image onCurrent:current forTotal:total onChunk:currentChunk forChunks:totalChunks iCloudProgress:iCloudProgress];
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
        // Determine the present view controller
        UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        }

        // Inform user that the upload task completed
        UIAlertController* alert = [UIAlertController
                    alertControllerWithTitle:NSLocalizedString(@"imageUploadCompleted_title", @"Upload Completed")
                    message:(self.totalUploadedImages > 1) ? [NSString stringWithFormat:@"%ld %@", (long)self.totalUploadedImages, NSLocalizedString(@"imageUploadCompleted_message>1", @"images/videos uploaded to your Piwigo server.")] : [NSString stringWithFormat:@"%ld %@", (long)self.totalUploadedImages, NSLocalizedString(@"imageUploadCompleted_message", @"image/video uploaded to your Piwigo server.")]
                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertOkButton", @"OK")
                    style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction * action) {
                        // Initialise counters for the next upload task
                        [self.uploadProgress setProgress:0 animated:NO];
                        self.totalUploadedImages = 0;
                        self.currentImage = 1;

                        // Update the local album table view
                        if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
                        {
                            [self.delegate imageUploaded:image placeInQueue:rank outOf:totalInQueue withResponse:response];
                        }
                        
                        // Submit request to moderator (Community plugin)
                        if ([[ImageUploadManager sharedInstance].uploadedImagesToBeModerated length] > 1) {
                            [self moderateImages:[ImageUploadManager sharedInstance].uploadedImagesToBeModerated
                                     uploadedToCategoryId:image.categoryToUploadTo];
                        }

                        // Delete images from Photos library if requested
                        if ([Model sharedInstance].deleteImageAfterUpload) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                    // Delete images from the library
                                    [PHAssetChangeRequest deleteAssets:[ImageUploadManager sharedInstance].imageDeleteQueue];
                                } completionHandler:^(BOOL success, NSError *error) {
//                                    NSLog(@"Finished deleting asset. %@", (success ? @"Success." : error));
                                }];
                            });
                        }
                    }];
        
        [alert addAction:defaultAction];
        [topViewController presentViewController:alert animated:YES completion:nil];
    } else {
        // Update the local album table view
        if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
        {
            [self.delegate imageUploaded:image placeInQueue:rank outOf:totalInQueue withResponse:response];
        }
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

-(void)moderateImages:(NSString *)uploadedImages uploadedToCategoryId:(NSInteger)categoryId
{
    // Remove extra comma
    uploadedImages = [uploadedImages substringToIndex:(uploadedImages.length - 1)];
    
    // Determine if the uploaded image is moderated
//    NSArray *moderatedImages = [uploadedImages componentsSeparatedByString:@","];
//    NSLog(@"Community —> %ld image(s) to submit to moderator (album #%ld)", (long)[moderatedImages count], (long)categoryId);
//    NSLog(@"Community —> %@", uploadedImages);
    [UploadService getUploadedImageStatusById:uploadedImages
                                   inCategory:categoryId
                                   onProgress:nil
                                 OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
                                     
//             if ([[response objectForKey:@"stat"] isEqualToString:@"ok"]) {
//                 // Request received by server
//
//                 // When admin trusts user, pending answer is empty
//                 id pendingStatus = [[response objectForKey:@"result"] objectForKey:@"pending"];
//                 if (pendingStatus && [pendingStatus count]) {
//
//                     // Moderation pending?
//                     id pendingState = [pendingStatus objectAtIndex:0];
//                     if ([[pendingState objectForKey:@"state"] isEqualToString:@"moderation_pending"]) {
//
//                     }
//                     else {
//
//                     }
//                 } else {
//
//                 }
//             }
                                 }
                                    onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG_UPLOAD)
                                        NSLog(@"moderateImages error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                    }
     ];
}

@end
