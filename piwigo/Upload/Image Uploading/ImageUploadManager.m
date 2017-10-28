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
	// Create an imagesourceref
	CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    if (!source) {
#if defined(DEBUG)
        NSLog(@"Error: Could not create source");
#endif
    } else {
        // this is the type of image (e.g., public.jpeg)
        CFStringRef UTI = CGImageSourceGetType(source);
        
        // create a new data object and write the new image into it
        NSMutableData *dest_data = [NSMutableData data];
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
        if (!destination) {
    #if defined(DEBUG)
            NSLog(@"Error: Could not create image destination");
    #endif
            CFRelease(source);
        } else {
            // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
            CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
            BOOL success = NO;
            success = CGImageDestinationFinalize(destination);
            if (!success) {
    #if defined(DEBUG)
                NSLog(@"Error: Could not create data from image destination");
    #endif
                CFRelease(destination);
                CFRelease(source);
            } else {
                CFRelease(destination);
                CFRelease(source);
                return dest_data;
            }
        }
    }
    return imageData;
}

-(void)uploadNextImage
{
	// Another image to upload?
    if(self.imageUploadQueue.count <= 0)
	{
		self.isUploading = NO;
		return;
	}
	
    self.isUploading = YES;
    [Model sharedInstance].hasUploadedImages = YES;
	
    // Image to be uploaded
	ImageUpload *nextImageToBeUploaded = [self.imageUploadQueue firstObject];
	ALAsset *imageAsset = nextImageToBeUploaded.imageAsset;
    NSMutableDictionary *imageMetadata = [[[imageAsset defaultRepresentation] metadata] mutableCopy];
    UIImage *originalImage = [UIImage imageWithCGImage:[[imageAsset defaultRepresentation] fullResolutionImage]];

    // strip GPS data if user requested it in Settings:
#if defined(DEBUG)
    NSLog(@"%@",imageMetadata);
#endif
    if([Model sharedInstance].stripGPSdataOnUpload) [imageMetadata setObject:@"" forKey:(NSString *)kCGImagePropertyGPSDictionary];

    // Video or Photo ?
    NSData *imageData = nil; NSString *mimeType = @"";
    if ([imageAsset valueForProperty:ALAssetPropertyType] == ALAssetTypeVideo) {
        
        // Can we upload videos to the Piwigo Server ?
        if(![Model sharedInstance].canUploadVideos) {

            // Release dictionary
            imageMetadata = nil;
            
            // Inform user that he/she cannot upload videos
            [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                          andMessage:NSLocalizedString(@"videoUploadError_message", @"You need to add the extension \"VideoJS\" and edit your local config file to allow video to be uploaded to your Piwigo.")
                         forRetrying:NO
                           withImage:nextImageToBeUploaded];
            return;
        }
        
        // Only webm, webmv, ogv, m4v, mp4 are compatible with piwigo-videojs extension
        NSString *fileExt = [[nextImageToBeUploaded.image pathExtension] lowercaseString];
        if ((([fileExt isEqualToString:@"mp4"]) && ([[Model sharedInstance].uploadFileTypes containsString:@"mp4"])) ||
            (([fileExt isEqualToString:@"m4v"]) && ([[Model sharedInstance].uploadFileTypes containsString:@"m4v"])) ) {
            // Prepare MIME type
            mimeType = @"video/mp4";
        } else if ((([fileExt isEqualToString:@"ogg"]) && ([[Model sharedInstance].uploadFileTypes containsString:@"ogg"])) ||
                   (([fileExt isEqualToString:@"ogv"]) && ([[Model sharedInstance].uploadFileTypes containsString:@"ogv"])) ) {
            // Prepare MIME type
            mimeType = @"video/ogg";
        } else if ((([fileExt isEqualToString:@"webm"])  && ([[Model sharedInstance].uploadFileTypes containsString:@"webm"] )) ||
                   (([fileExt isEqualToString:@"webmv"]) && ([[Model sharedInstance].uploadFileTypes containsString:@"webmv"])) ) {
            // Prepare MIME type
            mimeType = @"video/webm";
        } else {
            if ([fileExt isEqualToString:@"mov"]) {
                // Prepare MIME type
                mimeType = @"video/mp4";
                // Replace file extension
                nextImageToBeUploaded.image = [[nextImageToBeUploaded.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp4"];
            } else {
                // Release dictionary
                imageMetadata = nil;
                
                // This file won't be compatible!
                [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                              andMessage:NSLocalizedString(@"videoUploadError_format", @"Sorry, the video file format is not compatible with the extension \"VideoJS\".")
                             forRetrying:NO
                               withImage:nextImageToBeUploaded];
                return;
            }
        }
        
        // Prepare NSData representation (w/o metadata)
        ALAssetRepresentation *rep = [imageAsset defaultRepresentation];
        unsigned long repSize = (unsigned long)rep.size;
        Byte *buffer = (Byte *)malloc(repSize);
        NSUInteger length = [rep getBytes:buffer fromOffset:0 length:repSize error:nil];
        imageData = [NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES];
        imageMetadata = nil;
        
    } else {
        
        // Photo — resize image if requested in Settings
        CGFloat scale = [Model sharedInstance].resizeImageOnUpload ? [Model sharedInstance].photoResize / 100.0 : 1.0;
        CGSize newImageSize = CGSizeApplyAffineTransform(originalImage.size, CGAffineTransformMakeScale(scale, scale));
        UIImage *imageResized = [self scaleImage:originalImage toSize:newImageSize contentMode:UIViewContentModeScaleAspectFit];
        
        // Edit the meta data for the correct size:
        [imageMetadata setObject:@(imageResized.size.height) forKey:@"PixelHeight"];
        [imageMetadata setObject:@(imageResized.size.width) forKey:@"PixelWidth"];

        // Apply compression and append metadata
        CGFloat compressionQuality = [Model sharedInstance].resizeImageOnUpload ? [Model sharedInstance].photoQuality / 100.0 : .95;
        NSData *imageCompressed = UIImageJPEGRepresentation(imageResized, compressionQuality);
        imageData = [self writeMetadataIntoImageData:imageCompressed metadata:imageMetadata];
        imageMetadata = nil;
        
        // Prepare MIME type
        mimeType = @"image/jpeg";
    }
    
	// Append Tags
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in nextImageToBeUploaded.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
    // Prepare properties for upload
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamFileName : nextImageToBeUploaded.image,
									  kPiwigoImagesUploadParamTitle : nextImageToBeUploaded.title,
									  kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.categoryToUploadTo)],
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(nextImageToBeUploaded.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : nextImageToBeUploaded.author,
									  kPiwigoImagesUploadParamDescription : nextImageToBeUploaded.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy],
                                      kPiwigoImagesUploadParamMimeType : mimeType
									  };
	
    // Upload photo or video
	[UploadService uploadImage:imageData
			   withInformation:imageProperties
					onProgress:^(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks) {
						if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:)])
						{
							[self.delegate imageProgress:nextImageToBeUploaded onCurrent:current forTotal:total onChunk:currentChunk forChunks:totalChunks];
						}
					} OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
                        // Consider image job done
                        self.onCurrentImageUpload++;
						
                        // Set properties of uploaded image/video on Piwigo server
                        [self setImageResponse:response withInfo:imageProperties];
                        
						// The image must not be appended to the cache if it is moderated
                        if ([Model sharedInstance].usesCommunityPluginV29) {

                            // Append image to cache only if it is not moderated
                            [self isUploadedImageModerated:response inCategory:nextImageToBeUploaded.categoryToUploadTo];
                            
                        } else {
                            
                            // Increment number of images in category
                            [[[CategoriesData sharedInstance] getCategoryById:nextImageToBeUploaded.categoryToUploadTo] incrementImageSizeByOne];
                            
                            // Read image/video information and update cache
                            [self addImageDataToCategoryCache:response];
                        }
                        
                        // Remove image from queue and upload next one
                        [self uploadNextImageAndRemoveImageFromQueue:nextImageToBeUploaded withResponse:response];

					} onFailure:^(NSURLSessionTask *task, NSError *error) {
						NSString *fileExt = [[nextImageToBeUploaded.image pathExtension] uppercaseString];
                        if(error.code == -1016 &&
						   ([fileExt isEqualToString:@"MP4"] || [fileExt isEqualToString:@"M4V"] ||
                            [fileExt isEqualToString:@"OGG"] || [fileExt isEqualToString:@"OGV"] ||
                            [fileExt isEqualToString:@"WEBM"] || [fileExt isEqualToString:@"WEBMV"])
                           )
						{	// They need to check the VideoJS extension installation
                            [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                                          andMessage:NSLocalizedString(@"videoUploadConfigError_message", @"Please check the installation of \"VideoJS\" and the config file with LocalFiles Editor to allow video to be uploaded to your Piwigo.")
                                         forRetrying:NO
                                           withImage:nextImageToBeUploaded];
						}
						else
						{
#if defined(DEBUG)
							NSLog(@"ERROR IMAGE UPLOAD: %@", error);
#endif
                            // Inform user and propose to cancel or continue
                            [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
                                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), [error localizedDescription]]
                                         forRetrying:YES
                                           withImage:nextImageToBeUploaded];
						}
					}];
}

-(void)startUploadIfNeeded
{
	if(!self.isUploading)
	{
		[self uploadNextImage];
	}
}

-(void)showErrorWithTitle:(NSString *)title andMessage:(NSString *)message forRetrying:(BOOL)retry withImage:(ImageUpload *)image
{
    // Determine present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    // Present alert
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:title
                                message:message
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) {
                                        // Consider image job done
                                        self.onCurrentImageUpload++;

                                        // Empty queue
                                        while (self.imageUploadQueue.count > 0) {
                                            self.onCurrentImageUpload++;
                                            ImageUpload *nextImage = [self.imageUploadQueue firstObject];
                                            [self.imageUploadQueue removeObjectAtIndex:0];
                                            [self.imageNamesUploadQueue removeObjectForKey:nextImage.image];
                                        }
                                        // Tell user how many images have been downloaded
                                        if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
                                        {
                                            [self.delegate imageUploaded:image placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:nil];
                                        }
                                        // Stop uploading
                                        self.isUploading = NO;
                                    }];
    
    if (retry) {
        // Retry to upload the image
        UIAlertAction* retryAction = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
                                         // Upload image
                                         [self uploadNextImage];
                                     }];
        [alert addAction:retryAction];
    } else {
        // Upload next image
        UIAlertAction* nextAction = [UIAlertAction
                                     actionWithTitle:NSLocalizedString(@"alertNextButton", @"Next Image")
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction * action) {
                                         // Consider image job done
                                         self.onCurrentImageUpload++;

                                         // Remove image from queue and upload next one
                                         [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
                                     }];
        [alert addAction:nextAction];
    }
    
    [alert addAction:dismissAction];
    [topViewController presentViewController:alert animated:YES completion:nil];
}

-(void)uploadNextImageAndRemoveImageFromQueue:(ImageUpload *)image withResponse:(NSDictionary *)response
{
    // Remove image from queue (in both tables)
    [self.imageUploadQueue removeObjectAtIndex:0];
    [self.imageNamesUploadQueue removeObjectForKey:image.image];
    if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
    {
        [self.delegate imageUploaded:image placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:response];
    }

    // Upload next image
    [self uploadNextImage];
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
		
        // Set properties of image on Piwigo server
		[UploadService setImageInfoForImageWithId:imageId
								  withInformation:imageProperties
									   onProgress:^(NSProgress *progress) {
										   // progress
									   } OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
										   // completion
									   } onFailure:^(NSURLSessionTask *task, NSError *error) {
										   // fail
									   }];
		
	}
}

-(void)isUploadedImageModerated:(NSDictionary*)jsonResponse inCategory:(NSInteger)categoryId
{
    if([[jsonResponse objectForKey:@"stat"] isEqualToString:@"ok"])
    {
        NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
        NSString *imageId = [imageResponse objectForKey:@"image_id"];
        
        // Determine if the uploaded image is moderated
        [UploadService getUploadedImageStatusById:imageId
                                       inCategory:categoryId
                                       onProgress:^(NSProgress *progress) {
                                           // progress
                                       }
                                    OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {

                                        if ([[response objectForKey:@"stat"] isEqualToString:@"ok"]) {
                                            
                                            // When admin trusts user, pending answer is empty
                                            id pendingStatus = [[response objectForKey:@"result"] objectForKey:@"pending"];
                                            if (pendingStatus && [pendingStatus count]) {
                                                
                                                id pendingState = [pendingStatus objectAtIndex:0];
                                                if ([[pendingState objectForKey:@"state"] isEqualToString:@"moderation_pending"]) {
                                                    
                                                    // Moderation pending => Don't add this uploaded image/video to cache now
                                                
                                                } else {    // No moderation pending
                                                    
                                                    // Increment number of images in category
                                                    [[[CategoriesData sharedInstance] getCategoryById:categoryId] incrementImageSizeByOne];

                                                    // Read image/video information and update cache
                                                    [self addImageDataToCategoryCache:jsonResponse];
                                                }
                                            } else {        // No pending status response ! Trusted user

                                                // Increment number of images in category
                                                [[[CategoriesData sharedInstance] getCategoryById:categoryId] incrementImageSizeByOne];
                                                
                                                // Read image/video information and update cache
                                                [self addImageDataToCategoryCache:jsonResponse];
                                            }
                                         }
                                    }
                                        onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                            NSLog(@"isUploadedImageModerated error %ld: %@", (long)error.code, error.localizedDescription);
#endif
                                        }
         ];
    }
}

-(void)addImageDataToCategoryCache:(NSDictionary*)jsonResponse
{
    if([[jsonResponse objectForKey:@"stat"] isEqualToString:@"ok"])
    {
        NSDictionary *imageResponse = [jsonResponse objectForKey:@"result"];
        NSString *imageId = [imageResponse objectForKey:@"image_id"];
    
        // Read image information and update cache
        [ImageService getImageInfoById:[imageId integerValue]
                      ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                          //
                      } onFailure:^(NSURLSessionTask *task, NSError *error) {
                          //
                      }];
    }
}

@end
