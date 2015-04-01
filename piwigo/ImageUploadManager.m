//
//  ImageUploadManager.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageUploadManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <ImageIO/ImageIO.h>
#import "PhotosFetch.h"
#import "ImageUpload.h"
#import "PiwigoTagData.h"
#import "ImageService.h"
#import "CategoriesData.h"

@interface ImageUploadManager()

@property (nonatomic, assign) BOOL isUploading;
@property (nonatomic, assign) NSInteger maximumImagesForBatch;
@property (nonatomic, assign) NSInteger onCurrentImageUpload;

@end

@implementation ImageUploadManager

+(ImageUploadManager*)sharedInstance
{
	static ImageUploadManager *instance = nil;
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
		self.imageUploadQueue = [NSMutableArray new];
		self.imageNamesUploadQueue = [NSMutableDictionary new];
		self.isUploading = NO;
	}
	return self;
}

-(void)addImage:(ImageUpload*)image
{
	[self.imageUploadQueue addObject:image];
	self.maximumImagesForBatch++;
	[self startUploadIfNeeded];
	[self.imageNamesUploadQueue setObject:image.image forKey:image.image];
}

-(void)addImages:(NSArray*)images
{
	for(ImageUpload *image in images)
	{
		[self addImage:image];
	}
}

-(UIImage*)scaleImage:(UIImage*)image toSize:(CGSize)newSize contentMode:(UIViewContentMode)contentMode
{
	if (contentMode == UIViewContentModeScaleToFill)
	{
		return [self image:image byScalingToFillSize:newSize];
	}
	else if ((contentMode == UIViewContentModeScaleAspectFill) ||
			 (contentMode == UIViewContentModeScaleAspectFit))
	{
		CGFloat horizontalRatio   = image.size.width  / newSize.width;
		CGFloat verticalRatio     = image.size.height / newSize.height;
		CGFloat ratio;
		
		if (contentMode == UIViewContentModeScaleAspectFill)
			ratio = MIN(horizontalRatio, verticalRatio);
		else
			ratio = MAX(horizontalRatio, verticalRatio);
		
		CGSize  sizeForAspectScale = CGSizeMake(image.size.width / ratio, image.size.height / ratio);
		
		UIImage *newImage = [self image:image byScalingToFillSize:sizeForAspectScale];
		
		// if we're doing aspect fill, then the image still needs to be cropped
		
		if (contentMode == UIViewContentModeScaleAspectFill)
		{
			CGRect  subRect = CGRectMake(floor((sizeForAspectScale.width - newSize.width) / 2.0),
										 floor((sizeForAspectScale.height - newSize.height) / 2.0),
										 newSize.width,
										 newSize.height);
			newImage = [self image:newImage byCroppingToBounds:subRect];
		}
		
		return newImage;
	}
	
	return nil;
}
- (UIImage *)image:(UIImage*)image byCroppingToBounds:(CGRect)bounds
{
	CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], bounds);
	UIImage *croppedImage = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	return croppedImage;
}
- (UIImage*)image:(UIImage*)image byScalingToFillSize:(CGSize)newSize
{
	UIGraphicsBeginImageContext(newSize);
	[image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
	UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return newImage;
}
-(UIImage*)image:(UIImage*)image byScalingAspectFillSize:(CGSize)newSize
{
	return [self scaleImage:image toSize:newSize contentMode:UIViewContentModeScaleAspectFill];
}
-(UIImage*)image:(UIImage*)image byScalingAspectFitSize:(CGSize)newSize
{
	return [self scaleImage:image toSize:newSize contentMode:UIViewContentModeScaleAspectFit];
}

-(NSData*)writeMetadataIntoImageData:(NSData *)imageData metadata:(NSDictionary*)metadata
{
	// create an imagesourceref
	CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
	// this is the type of image (e.g., public.jpeg)
	CFStringRef UTI = CGImageSourceGetType(source);
	
	// create a new data object and write the new image into it
	NSMutableData *dest_data = [NSMutableData data];
	CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
	if (!destination) {
		NSLog(@"Error: Could not create image destination");
	}
	// add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
	CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
	BOOL success = NO;
	success = CGImageDestinationFinalize(destination);
	if (!success) {
		NSLog(@"Error: Could not create data from image destination");
	}
	CFRelease(destination);
	CFRelease(source);
	return dest_data;
}
-(void)uploadNextImage
{
	if(self.imageUploadQueue.count <= 0)
	{
		self.isUploading = NO;
		return;
	}
	
	self.isUploading = YES;
	
	ImageUpload *nextImageToBeUploaded = [self.imageUploadQueue firstObject];
	
	NSString *imageKey = nextImageToBeUploaded.image;
	ALAsset *imageAsset = [[PhotosFetch sharedInstance] getImageAssetInAlbum:nextImageToBeUploaded.localAlbum withImageName:imageKey];
	
	NSMutableDictionary *imageMetadata = [[[imageAsset defaultRepresentation] metadata] mutableCopy];
	UIImage *originalImage = [UIImage imageWithCGImage:[[imageAsset defaultRepresentation] fullResolutionImage]];
	CGSize newImageSize = CGSizeApplyAffineTransform(originalImage.size, CGAffineTransformMakeScale([Model sharedInstance].photoResize / 100.0, [Model sharedInstance].photoResize / 100.0));
	UIImage *imageResized = [self scaleImage:originalImage toSize:newImageSize contentMode:UIViewContentModeScaleAspectFit];
	
	// edit the meta data for the correct size:
	[imageMetadata setObject:@(imageResized.size.height) forKey:@"PixelHeight"];
	[imageMetadata setObject:@(imageResized.size.width) forKey:@"PixelWidth"];
	
	NSData *imageCompressed = UIImageJPEGRepresentation(imageResized, (100 - [Model sharedInstance].photoQuality) / 100.0);
	NSData *imageData = [self writeMetadataIntoImageData:imageCompressed metadata:imageMetadata];
	
	
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in nextImageToBeUploaded.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamFileName : nextImageToBeUploaded.image,
									  kPiwigoImagesUploadParamName : nextImageToBeUploaded.imageUploadName,
									  kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.categoryToUploadTo)],
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : nextImageToBeUploaded.author,
									  kPiwigoImagesUploadParamDescription : nextImageToBeUploaded.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy]
									  };
	
	[UploadService uploadImage:imageData
			   withInformation:imageProperties
					onProgress:^(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks) {
						
						if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:)])
						{
							[self.delegate imageProgress:nextImageToBeUploaded onCurrent:current forTotal:total onChunk:currentChunk forChunks:totalChunks];
						}
					} OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
						self.onCurrentImageUpload++;
						
						[[CategoriesData sharedInstance] getCategoryById:nextImageToBeUploaded.categoryToUploadTo].numberOfImages++;
						[self addImageDataToCategoryCache:response];
						[self setImageResponse:response withInfo:imageProperties];
						
						[self.imageUploadQueue removeObjectAtIndex:0];
						[self.imageNamesUploadQueue removeObjectForKey:imageKey];
						if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
						{
							[self.delegate imageUploaded:nextImageToBeUploaded placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:response];
						}
						
						[self uploadNextImage];
					} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
						if(error.code == -1016 &&
						   ([nextImageToBeUploaded.image rangeOfString:@".MOV"].location != NSNotFound ||
						   [nextImageToBeUploaded.image rangeOfString:@".mov"].location != NSNotFound))
						{	// they need to install the VideoJS plugin
							[UIAlertView showWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
											   message:NSLocalizedString(@"videoUploadError_message", @"You need to add the plugin \"VideoJS\" and edit your local config file to allow video to be uploaded to your Piwigo")
									 cancelButtonTitle:NSLocalizedString(@"alertOkayButton", @"Okay")
									 otherButtonTitles:nil
											  tapBlock:nil];
						}
						else
						{
							NSLog(@"ERROR IMAGE UPLOAD: %@", error);
							[self showUploadError:error];
						}
						
						[self.imageUploadQueue removeObjectAtIndex:0];
						[self.imageNamesUploadQueue removeObjectForKey:imageKey];
						if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
						{
							[self.delegate imageUploaded:nextImageToBeUploaded placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:nil];
						}
						
						[self uploadNextImage];
					}];
}

-(void)startUploadIfNeeded
{
	if(!self.isUploading)
	{
		[self uploadNextImage];
	}
}

-(void)showUploadError:(NSError*)error
{
	[UIAlertView showWithTitle:@"Upload Error"
					   message:[NSString stringWithFormat:@"Could not upload your image. Error: %@", [error localizedDescription]]
			 cancelButtonTitle:@"Okay"
			 otherButtonTitles:nil
					  tapBlock:nil];
}

-(void)setIsUploading:(BOOL)isUploading
{
	_isUploading = isUploading;
	
	if(!isUploading)
	{
		self.maximumImagesForBatch = 0;
		self.onCurrentImageUpload = 1;
		[UIApplication sharedApplication].idleTimerDisabled = NO;
	}
	else
	{
		[UIApplication sharedApplication].idleTimerDisabled = YES;
	}
}

-(void)setMaximumImagesForBatch:(NSInteger)maximumImagesForBatch
{
	_maximumImagesForBatch = maximumImagesForBatch;
	
	if([self.delegate respondsToSelector:@selector(imagesToUploadChanged:)])
	{
		[self.delegate imagesToUploadChanged:maximumImagesForBatch];
	}
}

-(NSInteger)getIndexOfImage:(ImageUpload*)image
{
	return [self.imageUploadQueue indexOfObject:image];
}

-(void)setImageResponse:(NSDictionary*)jsonResponse withInfo:(NSDictionary*)imageProperties
{
	if([[jsonResponse objectForKey:@"stat"] isEqualToString:@"ok"])
	{
		NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
		NSString *imageId = [imageResponse objectForKey:@"image_id"];
		
		[UploadService setImageInfoForImageWithId:imageId
								  withInformation:imageProperties
									   onProgress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
										   // progress
									   } OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
										   // completion
									   } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
										   // fail
									   }];
		
	}
}

-(void)addImageDataToCategoryCache:(NSDictionary*)jsonResponse
{
	
	NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
	[ImageService getImageInfoById:[[imageResponse objectForKey:@"image_id"] integerValue]
				  ListOnCompletion:^(AFHTTPRequestOperation *operation, PiwigoImageData *imageData) {
					  //
				  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
					  //
				  }];
}


@end
