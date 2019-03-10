//
//  AsyncImageActivityItemProvider.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>

#import "AsyncImageActivityItemProvider.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "Model.h"
#import "PhotosFetch.h"

NSString * const kPiwigoNotificationDidShareImage = @"kPiwigoNotificationDidShareImage";
NSString * const kPiwigoNotificationCancelDownloadImage = @"kPiwigoNotificationCancelDownloadImage";

@interface AsyncImageActivityItemProvider ()

@property (nonatomic, strong) PiwigoImageData* imageData;       // Image data
@property (nonatomic, strong) NSURLSessionDownloadTask *task;   // Download task
@property (nonatomic, strong) NSURL *imageFilePath;             // Image file path
@property (nonatomic, strong) NSString *alertTitle;             // Used if task cancels or fails
@property (nonatomic, strong) NSString *alertMessage;           // Used if task cancels or fails

@end

@implementation AsyncImageActivityItemProvider

-(instancetype)initWithPlaceholderImage:(PiwigoImageData *)imageData
{
    // Thumbnail image may be used as placeholder image
    NSString *thumbnailStr = [imageData getURLFromImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultThumbnailSize];
    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailStr];
    UIImageView *thumb = [UIImageView new];
    [thumb setImageWithURL:thumbnailURL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
    UIImage *thumbnail = thumb.image ? thumb.image : [UIImage imageNamed:@"placeholderImage"];

    self = [super initWithPlaceholderItem:thumbnail];
    self.imageData = imageData;
    return self;
}

/****************************************************
 The item method runs on a secondary thread using an NSOperationQueue
 (UIActivityItemProvider subclasses NSOperation).
 The implementation of this method loads an image from the Piwigo server.
 ******************************************************/
- (id)item
{
    // Notify the delegate on the main thread that the processing is beginning.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProviderPreprocessingDidBegin:self withTitle:NSLocalizedString(@"downloadingImage", @"Downloading Photo")];
    });

    // Register image share methods to perform on completion
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishSharingImage) name:kPiwigoNotificationDidShareImage object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelDownloadImageTask) name:kPiwigoNotificationCancelDownloadImage object:nil];

    // Select the most appropriate image size (infinity when undefined)
    // See https://makeawebsitehub.com/social-media-image-sizes-cheat-sheet/
    // High resolution for: AirDrop, Copy, Mail, Message, iBooks, Flickr, Print, SaveToCameraRoll
#if defined(DEBUG_SHARE)
    NSLog(@"=> Activity: %@", self.activityType);
#endif
    NSInteger minSize = NSIntegerMax;
    if (@available(iOS 10, *)) {
        if ([self.activityType isEqualToString:UIActivityTypeAssignToContact]) {
            // Assign to contact
            minSize = 1024;
        }
        else if ([self.activityType isEqualToString:UIActivityTypePostToFacebook]) {
            // Facebook
            minSize = 1200;
        }
        else if ([self.activityType isEqualToString:UIActivityTypePostToTencentWeibo]) {
            // Weibo
            minSize = 640;  // 9 images max + 1 video
        }
        else if ([self.activityType isEqualToString:UIActivityTypePostToTwitter]) {
            // Twitter
            minSize = 880;  // 4 images max
        }
        else if ([self.activityType isEqualToString:UIActivityTypePostToWeibo]) {
            // Weibo
            minSize = 640;  // 9 images max + 1 video
        }
        else if ([self.activityType isEqualToString:kPiwigoActivityTypePostToWhatsApp]) {
            // WhatsApp
            minSize = 1920;
        }
        else if ([self.activityType isEqualToString:kPiwigoActivityTypePostToSignal]) {
            // Signal
            minSize = 1920;
        }
        else if ([self.activityType isEqualToString:kPiwigoActivityTypeMessenger]) {
            // Messenger
            minSize = 1920;
        }
        else if ([self.activityType isEqualToString:kPiwigoActivityTypePostInstagram]) {
            // Instagram
            minSize = 1080;
        }
    }
    
    // Download image synchronously
    self.imageFilePath = nil;
    [self downloadSynchronouslyImageOfMinimumSize:minSize];

    // Cancel item task if download failed
    if (self.alertTitle) {
        // Cancel task
        [self cancel];

        // Notify the delegate on the main thread that the processing is cancelled
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate imageActivityItemProviderPreprocessingDidEnd:self withImageId:self.imageData.imageId];
        });
        return self.placeholderItem;
    }
    
    // Retrieve image from downloaded file
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:[self.imageFilePath path]];
    NSMutableData *imageDataFile = [NSMutableData dataWithContentsOfURL:self.imageFilePath];
    
    // Prepare file before sharing
    [self modifyImage:image withData:imageDataFile];

    // Cancel item task if image preparation failed
    if (self.alertTitle) {
        // Cancel task
        [self cancel];

        // Notify the delegate on the main thread that the processing is cancelled.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate imageActivityItemProviderPreprocessingDidEnd:self withImageId:self.imageData.imageId];
        });
        return self.placeholderItem;
    }
    
    // Notify the delegate on the main thread to show how it makes progress.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:1.0];
    });

    // Notify the delegate on the main thread that the processing has finished.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProviderPreprocessingDidEnd:self withImageId:self.imageData.imageId];
    });

    // Return image to share
    return self.imageFilePath;
}

-(void)downloadSynchronouslyImageOfMinimumSize:(NSInteger)minSize
{
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    self.task = [ImageService downloadImage:self.imageData
                              ofMinimumSize:minSize
                     onProgress:^(NSProgress *progress) {
                         // Notify the delegate on the main thread to show how it makes progress.
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:(0.75 * progress.fractionCompleted)];
                         });
                     }
              completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                  // Any error ?
                  if (error.code) {
                      // Failed
                      self.alertTitle = NSLocalizedString(@"downloadImageFail_title", @"Download Fail");
                      self.alertMessage = [NSString stringWithFormat:NSLocalizedString(@"downloadImageFail_message", @"Failed to download image!\n%@"), [error localizedDescription]];
                      dispatch_semaphore_signal(sema);
                  }
                  else {
                      // Retrieve image from file
                      self.imageFilePath = filePath;
                      dispatch_semaphore_signal(sema);
                  }
              }
    ];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    sema = nil;
}

-(void)modifyImage:(UIImage *)originalImage withData:(NSMutableData *)originalDataFile
{
    // Return immediately if no image (user tapped Cancel for example)
    if (!originalImage || !originalDataFile) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate imageActivityItemProviderPreprocessingDidEnd:self withImageId:self.imageData.imageId];
        });
        return;
    }
    
    // Create CGI reference from image data (to retrieve complete metadata)
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFMutableDataRef) originalDataFile, NULL);
    if (!source) {
#if defined(DEBUG_SHARE)
        NSLog(@"Error: Could not create source");
#endif
        // Error
        self.alertTitle = NSLocalizedString(@"imageSaveError_title", @"Fail Saving Image");
        self.alertMessage = [NSString stringWithFormat:NSLocalizedString(@"imageSaveError_message", @"Failed to save image. Error: %@"), NSLocalizedString(@"imageUploadError_source", @"cannot create image source")];
        return;
    }
    
    // Notify the delegate on the main thread to show how it makes progress.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:0.8];
    });

    // Get metadata from image data
    NSMutableDictionary *imageMetadata = [(NSMutableDictionary*) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) mutableCopy];
#if defined(DEBUG_SHARE)
    NSLog(@"modifyImage finds metadata from data:%@",imageMetadata);
    NSLog(@"originalObject is %.0fw x %.0fh", originalImage.size.width, originalImage.size.height);
#endif
    
    // Strip GPS metadata if user requested it in Settings
    if (imageMetadata != nil)
    {
        if (@available(iOS 10, *)) {
            if ([self.activityType isEqualToString:UIActivityTypeAirDrop]) {
                if (![Model sharedInstance].shareMetadataTypeAirDrop) {
                    imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                }
            }
            else if ([self.activityType isEqualToString:UIActivityTypeAssignToContact]) {
                     if (![Model sharedInstance].shareMetadataTypeAssignToContact) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypeCopyToPasteboard]) {
                     if (![Model sharedInstance].shareMetadataTypeCopyToPasteboard) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypeMail]) {
                     if (![Model sharedInstance].shareMetadataTypeMail) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypeMessage]) {
                     if (![Model sharedInstance].shareMetadataTypeMessage) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypePostToFacebook]) {
                     if (![Model sharedInstance].shareMetadataTypePostToFacebook) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:kPiwigoActivityTypeMessenger]) {
                     if (![Model sharedInstance].shareMetadataTypeMessenger) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypePostToFlickr]) {
                     if (![Model sharedInstance].shareMetadataTypePostToFlickr) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:kPiwigoActivityTypePostInstagram]) {
                     if (![Model sharedInstance].shareMetadataTypePostInstagram) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:kPiwigoActivityTypePostToSignal]) {
                     if (![Model sharedInstance].shareMetadataTypePostToSignal) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:kPiwigoActivityTypePostToSnapchat]) {
                     if (![Model sharedInstance].shareMetadataTypePostToSnapchat) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypePostToTencentWeibo]) {
                     if (![Model sharedInstance].shareMetadataTypePostToTencentWeibo) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypePostToTwitter]) {
                     if (![Model sharedInstance].shareMetadataTypePostToTwitter) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypePostToVimeo]) {
                     if (![Model sharedInstance].shareMetadataTypePostToVimeo) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypePostToWeibo]) {
                     if (![Model sharedInstance].shareMetadataTypePostToWeibo) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:kPiwigoActivityTypePostToWhatsApp]) {
                     if (![Model sharedInstance].shareMetadataTypePostToWhatsApp) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if ([self.activityType isEqualToString:UIActivityTypeSaveToCameraRoll]) {
                     if (![Model sharedInstance].shareMetadataTypeSaveToCameraRoll) {
                         imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
                     }
            }
            else if (![Model sharedInstance].shareMetadataTypeOther) {
                imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
            }
        }
        else {
            // Single On/Off share metadata option (use first boolean)
            if(![Model sharedInstance].shareMetadataTypeAirDrop)
            {
                imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
            }
        }
    }
    
    // Notify the delegate on the main thread to show how it makes progress.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:0.85];
    });

    // Fix image metadata (size, type, etc.)
    imageMetadata = [ImageService fixMetadata:imageMetadata ofImage:originalImage];
    
    // Final metadata…
#if defined(DEBUG_SHARE)
    NSLog(@"modifyImage: metadata to share => %@",imageMetadata);
#endif
    
    // Create new image from original one because one cannot modify metadata of existing file
    CFStringRef UTI = CGImageSourceGetType(source);
    CFMutableDataRef imageDataRef = CFDataCreateMutable(nil, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(imageDataRef, UTI, 1, nil);
    CGImageDestinationAddImage(destination, originalImage.CGImage, nil);
    if(!CGImageDestinationFinalize(destination)) {
#if defined(DEBUG_UPLOAD)
        NSLog(@"Error: Could not retrieve imageData object");
#endif
        CFRelease(source);
        CFRelease(destination);
        CFRelease(imageDataRef);
        // Error
        self.alertTitle = NSLocalizedString(@"imageSaveError_title", @"Fail Saving Image");
        self.alertMessage = [NSString stringWithFormat:NSLocalizedString(@"imageSaveError_message", @"Failed to save image. Error: %@"), NSLocalizedString(@"imageUploadError_source", @"cannot create image source")];
        return;
    }
    NSData *newImageData = (__bridge  NSData *)imageDataRef;
    
    // Release memory
    CFRelease(source);
    CFRelease(destination);
    CFRelease(imageDataRef);

    // Notify the delegate on the main thread to show how it makes progress.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:0.9];
    });
    
    // Add metadata to final image
    NSData *newImageDataFile = [ImageService writeMetadata:imageMetadata intoImageData:newImageData];
    
    // Delete downloaded temporary file
    [[NSFileManager defaultManager] removeItemAtURL:self.imageFilePath error:nil];
    
    // Release memory
    imageMetadata = nil;
    originalDataFile = nil;
    
    // Notify the delegate on the main thread to show how it makes progress.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:0.95];
    });
    
    // Share image w/ or w/o private metadata
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:self.imageData.fileName];
    NSError *writeError = nil;
    [newImageDataFile writeToFile:filePath options:NSDataWritingAtomic error:&writeError];
    if (writeError) {
        NSLog(@"Error writing file: %@", writeError);
    }

    // Share image w/ or w/o private metadata
    self.imageFilePath = [NSURL fileURLWithPath:filePath];
    newImageData = nil;
}

-(void)cancelDownloadImageTask
{
    // Cancel image file download
    [self.task cancel];
}

-(void)didFinishSharingImage
{
    // Delete temporary image file if exists
    [[NSFileManager defaultManager] removeItemAtURL:self.imageFilePath error:nil];

    // Remove image share observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationDidShareImage object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationCancelDownloadImage object:nil];

    // Inform user in case of error after dismissing activity view controller
    if (self.alertTitle) {
        [self.delegate showErrorWithTitle:self.alertTitle andMessage:self.alertMessage];
    }
    
    // Release momory
    self.alertTitle = nil;
    self.alertMessage = nil;
    self.imageFilePath = nil;
}

@end
