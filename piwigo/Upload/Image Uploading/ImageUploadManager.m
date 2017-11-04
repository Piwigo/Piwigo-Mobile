//
//  ImageUploadManager.m
//  piwigo
//
//  Created by Spencer Baker on 2/3/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <ImageIO/ImageIO.h>
#import <Photos/Photos.h>

#import "ImageUploadManager.h"
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


#pragma mark -- Upload image queue management

-(void)addImages:(NSArray*)images
{
    for(ImageUpload *image in images)
    {
        [self addImage:image];
    }
}

-(void)addImage:(ImageUpload*)image
{
	[self.imageUploadQueue addObject:image];
	self.maximumImagesForBatch++;
	[self startUploadIfNeeded];
	[self.imageNamesUploadQueue setObject:image.image forKey:image.image];
}

-(void)startUploadIfNeeded
{
    if(!self.isUploading)
    {
        [self uploadNextImage];
    }
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

-(void)uploadNextImage
{
    // Another image or video to upload?
    if(self.imageUploadQueue.count <= 0)
    {
        self.isUploading = NO;
        return;
    }
    
    self.isUploading = YES;
    [Model sharedInstance].hasUploadedImages = YES;
    
    // Image or video to be uploaded
    ImageUpload *nextImageToBeUploaded = [self.imageUploadQueue firstObject];
    PHAsset *originalAsset = nextImageToBeUploaded.imageAsset;
    NSString *mimeType = @"";
    
    // Retrieve Photo, Live Photo or Video
    if (originalAsset.mediaType == PHAssetMediaTypeImage) {
        switch (originalAsset.mediaSubtypes) {
            case PHAssetMediaSubtypeNone:
            case PHAssetMediaSubtypePhotoPanorama:
            case PHAssetMediaSubtypePhotoHDR:
            case PHAssetMediaSubtypePhotoScreenshot:
            case PHAssetMediaSubtypePhotoLive:
                [self retrieveFullSizeAssetDataFromImage:nextImageToBeUploaded];
                break;
                
//            case PHAssetMediaSubtypePhotoLive:
//                [self retrieveFullSizeAssetDataFromLivePhoto:nextImageToBeUploaded];
//                break;
                
            default:
                break;
        }
    }
    else if (originalAsset.mediaType == PHAssetMediaTypeVideo) {
        // Can we upload videos to the Piwigo Server ?
        if(![Model sharedInstance].canUploadVideos) {
            
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
                // This file won't be compatible!
                [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                              andMessage:NSLocalizedString(@"videoUploadError_format", @"Sorry, the video file format is not compatible with the extension \"VideoJS\".")
                             forRetrying:NO
                               withImage:nextImageToBeUploaded];
                return;
            }
        }

        // Video upload allowed — Will wait for video download from iCloud if necessary
        [self retrieveFullSizeAssetDataFromVideo:nextImageToBeUploaded withMimeType:mimeType];
    }
    else if (originalAsset.mediaType == PHAssetMediaTypeAudio) {
        // No managed yet by Piwigo Server…
    }
}

-(void)uploadNextImageAndRemoveImageFromQueue:(ImageUpload *)image withResponse:(NSDictionary *)response
{
    // Remove image from queue (in both tables)
    [self.imageUploadQueue removeObjectAtIndex:0];
    [self.imageNamesUploadQueue removeObjectForKey:image.image];
    
    // Update progress infos
    if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
    {
        [self.delegate imageUploaded:image placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:response];
    }
    
    // Upload next image
    [self uploadNextImage];
}


#pragma mark -- Image, retrieve and modify before upload

-(void)retrieveFullSizeAssetDataFromImage:(ImageUpload *)image  // Asynchronous
{
//    __block NSData *assetData = nil;

    // Case of an image…
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    // Blocks the calling thread until image data is ready or an error occurs
    options.synchronous = NO;
    // Requests the most recent version of the image asset
    options.version = PHImageRequestOptionsVersionCurrent;
    // Requests the highest-quality image available, regardless of how much time it takes to load.
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    // Photos can download the requested video from iCloud
    options.networkAccessAllowed = YES;
    // The block Photos calls periodically while downloading the photo
    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
        NSLog(@"downloading Live Photo from iCloud — progress %lf",progress);
    };
    // Requests image…
    @autoreleasepool {
        [[PHImageManager defaultManager] requestImageDataForAsset:image.imageAsset options:options
                     resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
#if defined(DEBUG)
                         NSLog(@"retrieveFullSizeAssetDataFromImage returned info(%@)", info);
#endif
                         if (!info) {
                             NSLog(@"=> info = nil!");
                         }
                         
                         if ([info objectForKey:PHImageErrorKey]) {
                             NSError *error = [info valueForKey:PHImageErrorKey];
                             NSLog(@"=> Error : %@", error.description);
                         }

                         if (![[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
                             // Expected resource available
                             assert(imageData.length != 0);
                             [self modifyImage:image withData:imageData];
                         }
                     }
         ];
    }
}

//-(void)retrieveFullSizeAssetDataFromLivePhoto:(ImageUpload *)image   // Asynchronous
//{
//    __block NSData *assetData = nil;
//
//    // Case of an Live Photo…
//    PHLivePhotoRequestOptions *options = [[PHLivePhotoRequestOptions alloc] init];
//    // Requests the most recent version of the image asset
//    options.version = PHImageRequestOptionsVersionOriginal;
//    // Requests the highest-quality image available, regardless of how much time it takes to load.
//    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
//    // Photos can download the requested video from iCloud.
//    options.networkAccessAllowed = YES;
//    // The block Photos calls periodically while downloading the LivePhoto.
//    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
//        NSLog(@"downloading Live Photo from iCloud — progress %lf",progress);
//    };
//
//    // Requests Live Photo…
//    @autoreleasepool {
//        [[PHImageManager defaultManager] requestLivePhotoForAsset:image.imageAsset
//                   targetSize:CGSizeZero contentMode:PHImageContentModeDefault
//                      options:options resultHandler:^(PHLivePhoto *livePhoto, NSDictionary *info) {
//#if defined(DEBUG)
//                          NSLog(@"retrieveFullSizeAssetDataFromLivePhoto returned info(%@)", info);
//#endif
//                          if ([info objectForKey:PHImageErrorKey]) {
//                              NSError *error = [info valueForKey:PHImageErrorKey];
//                              NSLog(@"=> Error : %@", error.description);
//                          }
//
//                          if (![[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
//                              // Expected resource available
//                              NSArray<PHAssetResource*>* resources = [PHAssetResource assetResourcesForLivePhoto:livePhoto];
//                              // Extract still high resolution image and original video
//                              __block PHAssetResource *resImage = nil;
//                              [resources enumerateObjectsUsingBlock:^(PHAssetResource *res, NSUInteger idx, BOOL *stop) {
//                                  if (res.type == PHAssetResourceTypeFullSizePhoto) {
//                                      resImage = res;
//                                  }
//                              }];
//
//                              // Store resources
//                              NSURL *urlImage = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[image.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"]]];
//
//                              // Deletes temporary file if exists (might be incomplete, etc.)
//                              [[NSFileManager defaultManager] removeItemAtURL:urlImage error:nil];
//
//                              // Store temporarily still image and video, then extract data
//                              [[PHAssetResourceManager defaultManager] writeDataForAssetResource:resImage toFile:urlImage options:nil completionHandler:^(NSError * _Nullable error) {
//                                      if (error.code) {
//                                          NSLog(@"=> Error storing image: %@", error.description);
//                                      }
//                                      assetData = [[NSData dataWithContentsOfURL:urlImage] copy];
//                                      assert(assetData.length != 0);
//                                      // Modify image before upload if needed
//                                      [self modifyImage:image withData:assetData];
//                              }];
//                          }
//                      }
//         ];
//    }
//}

-(void)modifyImage:(ImageUpload *)image withData:(NSData *)originalData
{
    // Create CGI reference from asset
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) originalData, NULL);
    if (!source) {
#if defined(DEBUG)
        NSLog(@"Error: Could not create source");
#endif
        // =================>>>> Code what to do in that case !!!!
        return;
    }
    
    // Get metadata of image before removing GPS metadata or resizing image
    NSMutableDictionary *assetMetadata = [(NSMutableDictionary*) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) mutableCopy];
#if defined(DEBUG)
    NSLog(@"modifyImage finds metadata :%@",assetMetadata);
#endif

    // Strips GPS metadata if user requested it in Settings
    if([Model sharedInstance].stripGPSdataOnUpload && (assetMetadata != nil)) {
        
        // GPS dictionary
        NSMutableDictionary *GPSDictionary = [[assetMetadata objectForKey:(NSString *)kCGImagePropertyGPSDictionary] mutableCopy];
        if (GPSDictionary) {
#if defined(DEBUG)
            NSLog(@"modifyImage: GPS metadata = %@",GPSDictionary);
#endif
            [assetMetadata removeObjectForKey:(NSString *)kCGImagePropertyGPSDictionary];
        }
        
        // EXIF dictionary
        NSMutableDictionary *EXIFDictionary = [[assetMetadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
        if (EXIFDictionary) {
#if defined(DEBUG)
            NSLog(@"modifyImage: EXIF User Comment metadata = %@",[EXIFDictionary valueForKey:(NSString *)kCGImagePropertyExifUserComment]);
            NSLog(@"modifyImage: EXIF Subject Location metadata = %@",[EXIFDictionary valueForKey:(NSString *)kCGImagePropertyExifSubjectLocation]);
#endif
            [EXIFDictionary removeObjectForKey:(NSString *)kCGImagePropertyExifUserComment];
            [EXIFDictionary removeObjectForKey:(NSString *)kCGImagePropertyExifSubjectLocation];
            [assetMetadata setObject:EXIFDictionary forKey:(NSString *)kCGImagePropertyExifDictionary];
        }

        // Final metadata…
#if defined(DEBUG)
        NSLog(@"modifyImage: w/o {GPS} = %@",assetMetadata);
#endif
    }

    // Get original image
    UIImage *assetImage = [UIImage imageWithCGImage:CGImageSourceCreateImageAtIndex(source, 0, NULL)];

    // Resize and compress image if user requested it in Settings
    CFStringRef UTI = nil;
    UIImage *imageResized = nil;
    if ([Model sharedInstance].resizeImageOnUpload && ([Model sharedInstance].photoResize < 100.0)) {
        // Resize image
        CGFloat scale = [Model sharedInstance].photoResize / 100.0;
        CGSize newImageSize = CGSizeApplyAffineTransform(assetImage.size, CGAffineTransformMakeScale(scale, scale));
        imageResized = [self scaleImage:assetImage toSize:newImageSize contentMode:UIViewContentModeScaleAspectFit];

        // Change metadata for new size
        [assetMetadata setObject:@(imageResized.size.height) forKey:(NSString *)kCGImagePropertyPixelHeight];
        [assetMetadata setObject:@(imageResized.size.width) forKey:(NSString *)kCGImagePropertyPixelWidth];
    } else {
        imageResized = [assetImage copy];
    }
    
    // Apply compression if user requested it in Settings
    NSData *imageCompressed = nil;
    if ([Model sharedInstance].resizeImageOnUpload && ([Model sharedInstance].photoQuality < 100.0)) {
        // Compress image (only possible in JPEG)
        CGFloat compressionQuality = [Model sharedInstance].photoQuality / 100.0;
        imageCompressed = UIImageJPEGRepresentation(imageResized, compressionQuality);

        // Final image file will be in JPEG format
        UTI = kUTTypeJPEG;
        image.image = [[image.image stringByDeletingPathExtension] stringByAppendingPathExtension:@"JPG"];
    }
    
    // If compression failed or no compression requested
    if (!imageCompressed) {
        UTI = CGImageSourceGetType(source);
        CFMutableDataRef imageDataRef = CFDataCreateMutable(nil, 0);
        CGImageDestinationRef destination = CGImageDestinationCreateWithData(imageDataRef, UTI, 1, nil);
        CGImageDestinationAddImage(destination, imageResized.CGImage, nil);
        if(!CGImageDestinationFinalize(destination)) {
    #if defined(DEBUG)
            NSLog(@"Error: Could not retrieve imageData object");
    #endif
            // =================>>>> Code what to do in that case !!!!
            return;
        }
        imageCompressed = (__bridge  NSData *)imageDataRef;
        CFRelease(destination);
    }
    
    // Release original CGImageSourceRef
    CFRelease(source);
    
    // Add metadata to final image
    NSData *imageData = [self writeMetadataIntoImageData:imageCompressed metadata:assetMetadata];
    
    // Release metadata
    assetMetadata = nil;

    // Prepare MIME type
    NSString *mimeType = @"";
    mimeType = [self contentTypeForImageData:imageData];

    // Upload image with tags and properties
    [self uploadImage:image withData:imageData andMimeType:mimeType];
}

-(NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
    }
    return nil;
}


#pragma mark -- Video, retrieve and modify before upload

-(void)retrieveFullSizeAssetDataFromVideo:(ImageUpload *)image withMimeType:(NSString *)mimeType  // Asynchronous
{
    // Case of a video…
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    // Requests the most recent version of the image asset
    options.version = PHVideoRequestOptionsVersionCurrent;
    // Requests the highest-quality video available, regardless of how much time it takes to load.
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
    // Photos can download the requested video from iCloud.
    options.networkAccessAllowed = YES;
    // The block Photos calls periodically while downloading the video.
    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
        NSLog(@"downloading Video from iCloud — progress %lf",progress);
    };
    
    // Requests video…
    @autoreleasepool {
        [[PHImageManager defaultManager] requestAVAssetForVideo:image.imageAsset options:options
                resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
#if defined(DEBUG)
                    NSLog(@"retrieveFullSizeAssetDataFromVideo returned info(%@)", info);
#endif
                    if ([info objectForKey:PHImageErrorKey]) {
                        NSError *error = [info valueForKey:PHImageErrorKey];
                        NSLog(@"=> Error : %@", error.description);
                    }

                    if (![[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
                        // Expected resource available
                        // Writes to documents folder before uploading to Piwigo server
                        NSError *error;
                        AVURLAsset *avurlasset = (AVURLAsset*) asset;
                        NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:image.image]];

                        // Deletes temporary file if exists already (might be incomplete, etc.)
                        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
                        
                        // Writes temporary video file
                        if ([[NSFileManager defaultManager]
                            copyItemAtURL:avurlasset.URL toURL:fileURL error:&error]) {
        #if defined(DEBUG)
                            NSLog(@"Copied correctly at %@", fileURL.absoluteString);
        #endif
                            // Modifies video before upload to Piwigo server
                            [self modifyVideo:image atURL:fileURL withMimeType:mimeType];
                            }
                    }
                }
         ];
    }
}

-(void)modifyVideo:(ImageUpload *)image atURL:(NSURL *)fileURL withMimeType:(NSString *)mimeType
{
    // Video and metadata from asset
    __block NSData *assetData = nil;
    AVAsset *videoAsset = [AVAsset assetWithURL:fileURL];
    NSArray *assetMetadata = [videoAsset commonMetadata];

    // Strips GPS data if user requested it in Settings
    if (![Model sharedInstance].stripGPSdataOnUpload || (!assetMetadata)) {
        
        // Gets copy as NSData
        assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
        assert(assetData.length != 0);

        // Deletes temporary video file
        if ([[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]) {
#if defined(DEBUG)
            NSLog(@"Deleted correctly at %@", fileURL.absoluteString);
#endif
        }
        
        // Upload video with tags and properties
        [self uploadImage:image withData:assetData andMimeType:mimeType];
    }
    else
    {
        // Creates metadata without location data
        NSMutableArray *newAssetMetadata = [NSMutableArray array];
        for (AVMetadataItem *item in assetMetadata) {
            if ([item.commonKey isEqualToString:AVMetadataCommonKeyLocation]){
#if defined(DEBUG)
                NSLog(@"Location found: %@", item.stringValue);
#endif
            } else {
                [newAssetMetadata addObject:item];
            }
        }
        
        // Done if metadata did not contain location
        if (newAssetMetadata.count == assetMetadata.count) {
            
            // Gets copy as NSData
            assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
            assert(assetData.length != 0);

            // Deletes temporary video file
            if ([[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]) {
#if defined(DEBUG)
                NSLog(@"Deleted correctly at %@", fileURL.absoluteString);
#endif
            }

            // Upload video with tags and properties
            [self uploadImage:image withData:assetData andMimeType:mimeType];
        }
        else if ([videoAsset isExportable]) {
            
            // Export new asset from original asset
            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:AVAssetExportPresetPassthrough];
            
            // Filename is ("_" + name + ".mp4") in same directory
            NSURL *newFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[@"_" stringByAppendingString:[image.image stringByDeletingPathExtension]] stringByAppendingPathExtension:@"mp4"]]];
            exportSession.outputURL = newFileURL;
            exportSession.outputFileType = AVFileTypeMPEG4;
            exportSession.shouldOptimizeForNetworkUse = YES;

            // Deletes temporary file if exists already (might be incomplete, etc.)
            [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];

            // Video range
            CMTime start = kCMTimeZero;
            CMTimeRange range = CMTimeRangeMake(start, [videoAsset duration]);
            exportSession.timeRange = range;
            
            // Updated metadata
            exportSession.metadata = newAssetMetadata;
            
            // Export video
            [exportSession exportAsynchronouslyWithCompletionHandler:^{
                if ([exportSession status] == AVAssetExportSessionStatusCompleted)
                {
#if defined(DEBUG)
                    NSLog(@"Export sucess…");
#endif
                    // Gets copy as NSData
                    assetData = [[NSData dataWithContentsOfURL:newFileURL] copy];
                    assert(assetData.length != 0);

                    // Deletes temporary video files
                    if ([[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", fileURL.absoluteString);
#endif
                    }
                    if ([[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", newFileURL.absoluteString);
#endif
                    }
                    
                    // Upload video with tags and properties
                    [self uploadImage:image withData:assetData andMimeType:mimeType];
                }
                else if ([exportSession status] == AVAssetExportSessionStatusFailed)
                {
#if defined(DEBUG)
                    NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
#endif
                    // Deletes temporary video files
                    if ([[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", fileURL.absoluteString);
#endif
                    }
                    if ([[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", newFileURL.absoluteString);
#endif
                    }
                    
                }
                else if ([exportSession status] == AVAssetExportSessionStatusCancelled)
                {
#if defined(DEBUG)
                    NSLog(@"Export canceled");
#endif
                    // Deletes temporary video files
                    if ([[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", fileURL.absoluteString);
#endif
                    }
                    if ([[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", newFileURL.absoluteString);
#endif
                    }
                    
                }
                else
                {
#if defined(DEBUG)
                    NSLog(@"Export ??");
#endif
                    // Deletes temporary video files
                    if ([[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", fileURL.absoluteString);
#endif
                    }
                    if ([[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil]) {
#if defined(DEBUG)
                        NSLog(@"Deleted correctly at %@", newFileURL.absoluteString);
#endif
                    }
                    
                }
            }];
        }
        else {
            // Could not export a new video — What to do?
        }
    }
}


#pragma mark -- Upload image/video

-(void)uploadImage:(ImageUpload *)image withData:(NSData *)imageData andMimeType:(NSString *)mimeType
{
	// Append Tags
	NSMutableArray *tagIds = [NSMutableArray new];
	for(PiwigoTagData *tagData in image.tags)
	{
		[tagIds addObject:@(tagData.tagId)];
	}
	
    // Prepare properties for upload
	NSDictionary *imageProperties = @{
									  kPiwigoImagesUploadParamFileName : image.image,
									  kPiwigoImagesUploadParamTitle : image.title,
									  kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(image.categoryToUploadTo)],
									  kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(image.privacyLevel)],
									  kPiwigoImagesUploadParamAuthor : image.author,
									  kPiwigoImagesUploadParamDescription : image.imageDescription,
									  kPiwigoImagesUploadParamTags : [tagIds copy],
                                      kPiwigoImagesUploadParamMimeType : mimeType
									  };
	
    // Upload photo or video
	[UploadService uploadImage:imageData
			   withInformation:imageProperties
					onProgress:^(NSInteger current, NSInteger total, NSInteger currentChunk, NSInteger totalChunks) {
						if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:)])
						{
							[self.delegate imageProgress:image onCurrent:current forTotal:total onChunk:currentChunk forChunks:totalChunks];
						}
					} OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
                        // Consider image job done
                        self.onCurrentImageUpload++;
						
                        // Set properties of uploaded image/video on Piwigo server
                        [self setImageResponse:response withInfo:imageProperties];
                        
						// The image must not be appended to the cache if it is moderated
                        if ([Model sharedInstance].usesCommunityPluginV29) {

                            // Append image to cache only if it is not moderated
                            [self isUploadedImageModerated:response inCategory:image.categoryToUploadTo];
                            
                        } else {
                            
                            // Increment number of images in category
                            [[[CategoriesData sharedInstance] getCategoryById:image.categoryToUploadTo] incrementImageSizeByOne];
                            
                            // Read image/video information and update cache
                            [self addImageDataToCategoryCache:response];
                        }
                        
                        // Remove image from queue and upload next one
                        [self uploadNextImageAndRemoveImageFromQueue:image withResponse:response];

					} onFailure:^(NSURLSessionTask *task, NSError *error) {
						NSString *fileExt = [[image.image pathExtension] uppercaseString];
                        if(error.code == -1016 &&
						   ([fileExt isEqualToString:@"MP4"] || [fileExt isEqualToString:@"M4V"] ||
                            [fileExt isEqualToString:@"OGG"] || [fileExt isEqualToString:@"OGV"] ||
                            [fileExt isEqualToString:@"WEBM"] || [fileExt isEqualToString:@"WEBMV"])
                           )
						{	// They need to check the VideoJS extension installation
                            [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                                          andMessage:NSLocalizedString(@"videoUploadConfigError_message", @"Please check the installation of \"VideoJS\" and the config file with LocalFiles Editor to allow video to be uploaded to your Piwigo.")
                                         forRetrying:NO
                                           withImage:image];
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
                                           withImage:image];
						}
					}];
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


#pragma mark -- Finish image upload

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


#pragma mark -- Scale, crope, etc. image before upload

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
    // NOP if metadata == nil
    if (!metadata) return imageData;
    
    // Create an imagesourceref
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    if (!source) {
#if defined(DEBUG)
        NSLog(@"Error: Could not create source");
#endif
    } else {
        // Type of image (e.g., public.jpeg)
        CFStringRef UTI = CGImageSourceGetType(source);
        
        // Create a new data object and write the new image into it
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

@end
