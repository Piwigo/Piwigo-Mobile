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
@property (nonatomic, strong) NSData *imageData;
@property (nonatomic, assign) NSInteger onCurrentImageUpload;
@property (nonatomic, assign) NSInteger current;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) NSInteger currentChunk;
@property (nonatomic, assign) NSInteger totalChunks;
@property (nonatomic, assign) CGFloat iCloudProgress;

@end

//#ifndef DEBUG_UPLOAD
//#define DEBUG_UPLOAD
//#endif

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
        self.imageNamesUploadQueue = [NSMutableArray new];
        self.imageDeleteQueue = [NSMutableArray new];
        self.uploadedImagesToBeModerated = [NSString new];
        self.isUploading = NO;
        
        self.current = 0;
        self.total = 1;
        self.currentChunk = 1;
        self.totalChunks = 1;
    }
    return self;
}


#pragma mark - Upload image queue management

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
    
    // The file name extension may change e.g. MOV => MP4, HEIC => JPG
    [self.imageNamesUploadQueue addObject:[image.fileName stringByDeletingPathExtension]];
}

-(void)startUploadIfNeeded
{
    if(!self.isUploading)
    {
        self.imageDeleteQueue = [NSMutableArray new];
        self.uploadedImagesToBeModerated = @"";
        [self uploadNextImage];
    }
}

-(void)setIsUploading:(BOOL)isUploading
{
    _isUploading = isUploading;
    
    if(!isUploading)
    {
        // Reset variables
        self.maximumImagesForBatch = 0;
        self.onCurrentImageUpload = 1;

        // Allow system sleep
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
    else
    {
        // Prevent system sleep
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
        // Stop uploading
        self.isUploading = NO;
        return;
    }
    
    self.iCloudProgress = -1.0;         // No iCloud download (will become positive if any)
    self.isUploading = YES;
    [Model sharedInstance].hasUploadedImages = YES;
    
    // Image or video to be uploaded
    ImageUpload *nextImageToBeUploaded = [self.imageUploadQueue firstObject];
    NSString *fileExt = [[nextImageToBeUploaded.fileName pathExtension] lowercaseString];
    PHAsset *originalAsset = nextImageToBeUploaded.imageAsset;
    
    // Retrieve Photo, Live Photo or Video
    if (originalAsset.mediaType == PHAssetMediaTypeImage) {
        
        // Chek that the image format will be accepted by the Piwigo server
        if ((![[Model sharedInstance].uploadFileTypes containsString:fileExt]) &&
            (![[Model sharedInstance].uploadFileTypes containsString:@"jpg"]) ) {
            [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_format", @"Sorry, image files with extensions .%@ and .jpg are not accepted by the Piwigo server."), [fileExt uppercaseString]]
                         forRetrying:NO
                           withImage:nextImageToBeUploaded];
            return;
        }
        
        // Image file type accepted
        switch (originalAsset.mediaSubtypes) {
//            case PHAssetMediaSubtypePhotoLive:
//                [self retrieveFullSizeAssetDataFromLivePhoto:nextImageToBeUploaded];
//                break;
            case PHAssetMediaSubtypeNone:
            case PHAssetMediaSubtypePhotoPanorama:
            case PHAssetMediaSubtypePhotoHDR:
            case PHAssetMediaSubtypePhotoScreenshot:
            case PHAssetMediaSubtypePhotoLive:
            case PHAssetMediaSubtypePhotoDepthEffect:
            default:                                            // Case of GIF image
                // Image upload allowed — Will wait for image file download from iCloud if necessary
                [self retrieveImageFromiCloudForAsset:nextImageToBeUploaded];
                break;
        }
    }
    else if (originalAsset.mediaType == PHAssetMediaTypeVideo) {

        // Videos are always exported in MP4 format (whenever possible)
        fileExt = @"mp4";
        nextImageToBeUploaded.fileName = [[nextImageToBeUploaded.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:fileExt];

        // Chek that the video format is accepted by the Piwigo server
        if (![[Model sharedInstance].uploadFileTypes containsString:fileExt]) {
            [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_format", @"Sorry, video files with extension .%@ are not accepted by the Piwigo server."), [fileExt uppercaseString]]
                         forRetrying:NO
                           withImage:nextImageToBeUploaded];
            return;
        }
        
        // Video upload allowed — Will wait for video file download from iCloud if necessary
        [self retrieveFullSizeAssetDataFromVideo:nextImageToBeUploaded];
    }
    else if (originalAsset.mediaType == PHAssetMediaTypeAudio) {

        // Not managed by Piwigo iOS yet…
        [self showErrorWithTitle:NSLocalizedString(@"audioUploadError_title", @"Audio Upload Error")
                      andMessage:NSLocalizedString(@"audioUploadError_format", @"Sorry, audio files are not supported by Piwigo Mobile yet.")
                     forRetrying:NO
                       withImage:nextImageToBeUploaded];
        return;

        // Chek that the audio format is accepted by the Piwigo server
//        if (![[Model sharedInstance].uploadFileTypes containsString:fileExt]) {
//            [self showErrorWithTitle:NSLocalizedString(@"audioUploadError_title", @"Audio Upload Error")
//                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"audioUploadError_format", @"Sorry, audio files with extension .%@ are not accepted by the Piwigo server."), [fileExt uppercaseString]]
//                         forRetrying:NO
//                           withImage:nextImageToBeUploaded];
//            return;
//        }

        // Audio upload allowed — Will wait for audio file download from iCloud if necessary
//        [self retrieveFullSizeAssetDataFromAudio:nextImageToBeUploaded];
    }
}

-(void)uploadNextImageAndRemoveImageFromQueue:(ImageUpload *)image withResponse:(NSDictionary *)response
{
    // Remove image from queue (in both tables)
    if (self.imageUploadQueue.count > 0) {                  // Added to prevent crash
        [self.imageUploadQueue removeObjectAtIndex:0];
        [self.imageNamesUploadQueue removeObject:[image.fileName stringByDeletingPathExtension]];

        // Update progress infos
        if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
        {
            [self.delegate imageUploaded:image placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:response];
        }
    }
    
    // Upload next image
    [self uploadNextImage];
}


#pragma mark - Image, retrieve and modify before upload

-(void)retrieveImageFromiCloudForAsset:(ImageUpload *)image
{
#if defined(DEBUG_UPLOAD)
    NSLog(@"retrieveImageFromiCloudForAsset starting...");
#endif
    // Case of an image…
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    // Does not block the calling thread until image data is ready or an error occurs
    options.synchronous = NO;
    // Requests the most recent version of the image asset
    options.version = PHImageRequestOptionsVersionCurrent;
    // Requests the highest-quality image available, regardless of how much time it takes to load.
    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    // Photos can download the requested video from iCloud
    options.networkAccessAllowed = YES;
    // Requests Photos to resize the image according to user settings
    CGSize size = PHImageManagerMaximumSize;
    options.resizeMode = PHImageRequestOptionsResizeModeExact;
    if ([Model sharedInstance].resizeImageOnUpload && [Model sharedInstance].photoResize < 100.0) {
        CGFloat scale = [Model sharedInstance].photoResize / 100.0;
        size = CGSizeMake(image.imageAsset.pixelWidth * scale, image.imageAsset.pixelHeight * scale);
        options.resizeMode = PHImageRequestOptionsResizeModeExact;
    }

    // The block Photos calls periodically while downloading the photo
    options.progressHandler = ^(double progress, NSError *error, BOOL* stop, NSDictionary* info) {
#if defined(DEBUG_UPLOAD)
        NSLog(@"downloading Photo from iCloud — progress %lf",progress);
#endif
        // The handler needs to update the user interface => Dispatch to main thread
        dispatch_async(dispatch_get_main_queue(), ^{

            self.iCloudProgress = progress;
            ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
            if (error) {
                // Inform user and propose to cancel or continue
                [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                              andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_iCloud", @"Could not retrieve image. Error: %@"), [error localizedDescription]]
                             forRetrying:YES
                               withImage:image];
                return;
            }
            else if (imageBeingUploaded.stopUpload) {
                // User wants to cancel the download
                *stop = YES;

                // Remove image from queue, update UI and upload next one
                self.maximumImagesForBatch--;
                [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
            }
            else {
                // Update progress bar(s)
                if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
                {
                    [self.delegate imageProgress:image onCurrent:self.current forTotal:self.total onChunk:self.currentChunk forChunks:self.totalChunks iCloudProgress:progress];
                }
            }
        });
    };
    
    // Requests image…
    @autoreleasepool {
        [[PHImageManager defaultManager] requestImageForAsset:image.imageAsset targetSize:size contentMode:PHImageContentModeDefault options:options resultHandler:
         ^(UIImage *imageObject, NSDictionary *info) {
#if defined(DEBUG_UPLOAD)
             NSLog(@"retrieveImageFromiCloudForAsset \"%@\" returned info(%@)", imageObject.comment, info);
             NSLog(@"got image %.0fw x %.0fh with orientation %ld", imageObject.size.width, imageObject.size.height, (long)imageObject.imageOrientation);
#endif
             if ([info objectForKey:PHImageErrorKey] || (imageObject.size.width == 0) || (imageObject.size.height == 0)) {
                 NSError *error = [info valueForKey:PHImageErrorKey];
                 // Inform user and propose to cancel or continue
                 [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                               andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_iCloud", @"Could not retrieve image. Error: %@"), [error localizedDescription]]
                              forRetrying:YES
                                withImage:image];
                 return;
             }
             
             // Fix orientation if needed
             UIImage *fixedImageObject = [self fixOrientationOfImage:imageObject];

             // Expected resource available
             [self retrieveFullSizeImageDataForAsset:image andObject:fixedImageObject];
         }];
    }
}

-(void)retrieveFullSizeImageDataForAsset:(ImageUpload *)image andObject:(UIImage *)imageObject
{
#if defined(DEBUG_UPLOAD)
    NSLog(@"retrieveFullSizeAssetDataFromImage starting...");
#endif
    // Case of an image…
    PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
    // Does not block the calling thread until image data is ready or an error occurs
    options.synchronous = NO;
    // Requests the most recent version of the image asset
    options.version = PHImageRequestOptionsVersionCurrent;
    // Requests a fast-loading image, possibly sacrificing image quality.
    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;
    // Photos can download the requested video from iCloud
    options.networkAccessAllowed = YES;

    // The block Photos calls periodically while downloading the photo
    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* info) {
#if defined(DEBUG_UPLOAD)
        NSLog(@"downloading Photo from iCloud — progress %lf",progress);
#endif
        // The handler needs to update the user interface => Dispatch to main thread
        dispatch_async(dispatch_get_main_queue(), ^{

            self.iCloudProgress = progress;
            ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
            if (error) {
                // Inform user and propose to cancel or continue
                [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                              andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_iCloud", @"Could not retrieve image. Error: %@"), [error localizedDescription]]
                             forRetrying:YES
                               withImage:image];
                return;
            }
            else if (imageBeingUploaded.stopUpload) {
                // User wants to cancel the download
                *stop = YES;
                
                // Remove image from queue, update UI and upload next one
                self.maximumImagesForBatch--;
                [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
            }
            else {
                // Update progress bar(s)
                if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
                {
                    [self.delegate imageProgress:image onCurrent:self.current forTotal:self.total onChunk:self.currentChunk forChunks:self.totalChunks iCloudProgress:progress];
                }
            }
        });
    };

    @autoreleasepool {
        if (@available(iOS 13.0, *)) {
            [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:image.imageAsset
                    options:options
              resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, CGImagePropertyOrientation orientation, NSDictionary * _Nullable info) {
#if defined(DEBUG_UPLOAD)
                     NSLog(@"retrieveFullSizeImageDataForAsset \"%@\" returned info(%@)", image.fileName, info);
                     NSLog(@"got image %.0fw x %.0fh with orientation:%ld", imageObject.size.width, imageObject.size.height, (long)orientation);
#endif
                     if ([info objectForKey:PHImageErrorKey] || (imageData.length == 0)) {
                         NSError *error = [info valueForKey:PHImageErrorKey];
                         // Inform user and propose to cancel or continue
                         [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                                       andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_iCloud", @"Could not retrieve image. Error: %@"), [error localizedDescription]]
                                      forRetrying:YES
                                        withImage:image];
                         return;
                     }

                     // Expected resource available
                     [self modifyImage:image withData:imageData andObject:imageObject];
            }];
        }
        else {
            [[PHImageManager defaultManager] requestImageDataForAsset:image.imageAsset
                      options:options
                resultHandler:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
#if defined(DEBUG_UPLOAD)
                     NSLog(@"retrieveFullSizeImageDataForAsset \"%@\" returned info(%@)", image.fileName, info);
                     NSLog(@"got image %.0fw x %.0fh with orientation:%ld", imageObject.size.width, imageObject.size.height, (long)orientation);
#endif
                     if ([info objectForKey:PHImageErrorKey] || (imageData.length == 0)) {
                         NSError *error = [info valueForKey:PHImageErrorKey];
                         // Inform user and propose to cancel or continue
                         [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                                       andMessage:[NSString stringWithFormat:NSLocalizedString(@"imageUploadError_iCloud", @"Could not retrieve image. Error: %@"), [error localizedDescription]]
                                      forRetrying:YES
                                        withImage:image];
                         return;
                     }

                     // Expected resource available
                     [self modifyImage:image withData:imageData andObject:imageObject];
                }];
        }
    }
}

-(void)modifyImage:(ImageUpload *)image withData:(NSData *)originalData andObject:(UIImage *)originalObject
{
    // Create CGI reference from image data (to retrieve complete metadata)
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFMutableDataRef) originalData, NULL);
    if (!source) {
#if defined(DEBUG_UPLOAD)
        NSLog(@"Error: Could not create source");
#endif
        // Inform user and propose to cancel or continue
        [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                  andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), NSLocalizedString(@"imageUploadError_source", @"cannot create image source")]
                 forRetrying:YES
                   withImage:image];
        return;
    }
    
    // Get metadata from image data
    NSMutableDictionary *imageMetadata = [(NSMutableDictionary*) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) mutableCopy];
#if defined(DEBUG_UPLOAD)
    NSLog(@"modifyImage finds metadata from data:%@",imageMetadata);
    NSLog(@"originalObject is %.0fw x %.0fh", originalObject.size.width, originalObject.size.height);
#endif
    
    // Strip GPS metadata if user requested it in Settings
    if([Model sharedInstance].stripGPSdataOnUpload && (imageMetadata != nil))
    {
        imageMetadata = [ImageService stripGPSdataFromImageMetadata:imageMetadata];
    }

    // Fix image metadata (size, type, etc.)
    imageMetadata = [ImageService fixMetadata:imageMetadata ofImage:originalObject];
    
    // Final metadata…
#if defined(DEBUG_UPLOAD)
    NSLog(@"modifyImage: metadata to upload => %@",imageMetadata);
#endif
    
    // Apply compression if user requested it in Settings, or convert to JPEG if necessary
    NSData *imageCompressed = nil;
    NSString *fileExt = [[image.fileName pathExtension] lowercaseString];
    if ([Model sharedInstance].compressImageOnUpload && ([Model sharedInstance].photoQuality < 100.0)) {
        // Compress image (only possible in JPEG)
        CGFloat compressionQuality = [Model sharedInstance].photoQuality / 100.0;
        imageCompressed = UIImageJPEGRepresentation(originalObject, compressionQuality);

        // Final image file will be in JPEG format
        image.fileName = [[image.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"JPG"];
    }
    else if (![[Model sharedInstance].uploadFileTypes containsString:fileExt]) {
        // Image in unaccepted file format for Piwigo server => convert to JPEG format
        imageCompressed = UIImageJPEGRepresentation(originalObject, 1.0);
        
        // Final image file will be in JPEG format
        image.fileName = [[image.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"JPG"];
    }
    
    // If compression failed or imageCompressed nil, try to use original image
    if (!imageCompressed) {
        CFStringRef UTI = CGImageSourceGetType(source);
        CFMutableDataRef imageDataRef = CFDataCreateMutable(nil, 0);
        CGImageDestinationRef destination = CGImageDestinationCreateWithData(imageDataRef, UTI, 1, nil);
        CGImageDestinationAddImage(destination, originalObject.CGImage, nil);
        if(!CGImageDestinationFinalize(destination)) {
#if defined(DEBUG_UPLOAD)
        NSLog(@"Error: Could not retrieve imageData object");
#endif
            CFRelease(source);
            CFRelease(destination);
            CFRelease(imageDataRef);
            // Inform user and propose to cancel or continue
            [self showErrorWithTitle:NSLocalizedString(@"imageUploadError_title", @"Image Upload Error")
                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), NSLocalizedString(@"imageUploadError_destination", @"cannot create image destination")]
                         forRetrying:YES
                           withImage:image];
            return;
        }
        imageCompressed = (__bridge  NSData *)imageDataRef;
        CFRelease(imageDataRef);
        CFRelease(destination);
    }
    
    // Release original CGImageSourceRef
    CFRelease(source);
    
    // Add metadata to final image
    self.imageData = [ImageService writeMetadata:imageMetadata intoImageData:imageCompressed];
    
    // Release memory
    imageCompressed = nil;
    imageMetadata = nil;
    originalObject = nil;
    originalData = nil;

    // Try to determine MIME type from image data
    NSString *mimeType = @"";
    mimeType = [self contentTypeForImageData:self.imageData];
    
    // Re-check filename extension if MIME type known
    if (mimeType != nil) {
        fileExt = [[image.fileName pathExtension] lowercaseString];
        NSString *expectedFileExtension = [self fileExtensionForImageData:self.imageData];
        if (![fileExt isEqualToString:expectedFileExtension]) {
            image.fileName = [[image.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:expectedFileExtension];
        }
    } else {
        // Could not determine image file format from image data,
        // keep file extension and use arbitrary mime type
        mimeType = @"image/jpg";
    }
    
    // Upload image with tags and properties
    [self uploadImage:image withMimeType:mimeType];
}

#pragma mark - MIME type and file extension sniffing

// See https://en.wikipedia.org/wiki/List_of_file_signatures
// https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context

// https://en.wikipedia.org/wiki/BMP_file_format
const char bmp[2] = {'B', 'M'};

// https://en.wikipedia.org/wiki/GIF
const char gif87a[6] = {'G', 'I', 'F', '8', '7', 'a'};
const char gif89a[6] = {'G', 'I', 'F', '8', '9', 'a'};

// https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
const char heic[12] = {0x00, 0x00, 0x00, 0x18, 'f', 't', 'y', 'p', 'h', 'e', 'i', 'c'};

// https://en.wikipedia.org/wiki/ILBM
const char iff[4] = {'F', 'O', 'R', 'M'};

// https://en.wikipedia.org/wiki/JPEG
const char jpg[3] = {0xff, 0xd8, 0xff};

// https://en.wikipedia.org/wiki/JPEG_2000
const char jp2[12] = {0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a};

// https://en.wikipedia.org/wiki/Portable_Network_Graphics
const char png[8] = {0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a};

// https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
const char psd[4] = {'8', 'B', 'P', 'S'};

// https://en.wikipedia.org/wiki/TIFF
const char tif_ii[4] = {'I','I', 0x2A, 0x00};
const char tif_mm[4] = {'M','M', 0x00, 0x2A};

// https://en.wikipedia.org/wiki/WebP
const char webp[4] = {'R', 'I', 'F', 'F'};

// https://en.wikipedia.org/wiki/ICO_(file_format)
const char win_ico[4] = {0x00, 0x00, 0x01, 0x00};
const char win_cur[4] = {0x00, 0x00, 0x02, 0x00};

-(NSString *)contentTypeForImageData:(NSData *)data {
    char bytes[12] = {0};
    [data getBytes:&bytes length:12];
    
    if (!memcmp(bytes, jpg, 3)) {
        return @"image/jpeg";
    } else if (!memcmp(bytes, heic, 12)) {
        return @"image/heic";
    } else if (!memcmp(bytes, png, 8)) {
        return @"image/png";
    } else if (!memcmp(bytes, gif87a, 6) || !memcmp(bytes, gif89a, 6)) {
        return @"image/gif";
    } else if (!memcmp(bytes, bmp, 2)) {
        return @"image/x-ms-bmp";
    } else if (!memcmp(bytes, psd, 4)) {
        return @"image/vnd.adobe.photoshop";
    } else if (!memcmp(bytes, iff, 4)) {
        return @"image/iff";
    } else if (!memcmp(bytes, webp, 4)) {
        return @"image/webp";
    } else if (!memcmp(bytes, win_ico, 4) || !memcmp(bytes, win_cur, 4)) {
        return @"image/x-icon";
    } else if (!memcmp(bytes, tif_ii, 4) || !memcmp(bytes, tif_mm, 4)) {
        return @"image/tiff";
    } else if (!memcmp(bytes, jp2, 12)) {
        return @"image/jp2";
    }

    return nil;
}

-(NSString *)fileExtensionForImageData:(NSData *)data {
    char bytes[12] = {0};
    [data getBytes:&bytes length:12];
    
    if (!memcmp(bytes, jpg, 3)) {
        return @"jpg";
    } else if (!memcmp(bytes, heic, 12)) {
        return @"heic";
    } else if (!memcmp(bytes, png, 8)) {
        return @"png";
    } else if (!memcmp(bytes, gif87a, 6) || !memcmp(bytes, gif89a, 6)) {
        return @"gif";
    } else if (!memcmp(bytes, bmp, 2)) {
        return @"bmp";
    } else if (!memcmp(bytes, psd, 4)) {
        return @"psd";
    } else if (!memcmp(bytes, iff, 4)) {
        return @"iff";
    } else if (!memcmp(bytes, webp, 4)) {
        return @"webp";
    } else if (!memcmp(bytes, win_ico, 4)) {
        return @"ico";
    } else if (!memcmp(bytes, win_cur, 4)) {
        return @"cur";
    } else if (!memcmp(bytes, tif_ii, 4) || !memcmp(bytes, tif_mm, 4)) {
        return @"tif";
    } else if (!memcmp(bytes, jp2, 12)) {
        return @"jp2";
    }
    
    return nil;
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
//#if defined(DEBUG_UPLOAD)
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
#pragma mark - Video, retrieve and modify before upload

-(void)retrieveFullSizeAssetDataFromVideo:(ImageUpload *)image  // Asynchronous
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
#if defined(DEBUG_UPLOAD)
        NSLog(@"downloading Video from iCloud — progress %lf",progress);
#endif
        // The handler needs to update the user interface => Dispatch to main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.iCloudProgress = progress;
            ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
            if (error) {
                // Inform user and propose to cancel or continue
                [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                              andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_iCloud", @"Could not retrieve video. Error: %@"), [error localizedDescription]]
                             forRetrying:YES
                               withImage:image];
                return;
            }
            else if (imageBeingUploaded.stopUpload) {
                // User wants to cancel the download
                *stop = YES;
                
                // Remove image from queue and upload next one
                self.maximumImagesForBatch--;
                [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
            }
            else {
                // Updates progress bar(s)
                if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
                {
                    NSLog(@"retrieveFullSizeAssetDataFromVideo: %.2f", progress);
                    [self.delegate imageProgress:image onCurrent:self.current forTotal:self.total onChunk:self.currentChunk forChunks:self.totalChunks iCloudProgress:progress];
                }
            }
        });
    };
    
    // Available export session presets?
    [[PHImageManager defaultManager] requestAVAssetForVideo:image.imageAsset
                                                    options:options
                                              resultHandler:^(AVAsset *avasset, AVAudioMix *audioMix, NSDictionary *info) {
                                                  
#if defined(DEBUG_UPLOAD)
        NSLog(@"=> Metadata: %@", avasset.metadata);
        NSLog(@"=> Creation date: %@", avasset.creationDate);
        NSLog(@"=> Exportable: %@", avasset.exportable ? @"Yes" : @"No");
        NSLog(@"=> Compatibility: %@", [AVAssetExportSession exportPresetsCompatibleWithAsset:avasset]);
        NSLog(@"=> Tracks: %@", avasset.tracks);
        for (AVAssetTrack *track in avasset.tracks) {
            if (track.mediaType == AVMediaTypeVideo)
                NSLog(@"=>       : %.f x %.f", track.naturalSize.width, track.naturalSize.height);
                NSMutableString *format = [[NSMutableString alloc] init];
                for (int i = 0; i < track.formatDescriptions.count; i++) {
                    CMFormatDescriptionRef desc =
                        (__bridge CMFormatDescriptionRef)track.formatDescriptions[i];
                    // Get String representation of media type (vide, soun, sbtl, etc.)
                    NSString *type = FourCCString(CMFormatDescriptionGetMediaType(desc));
                    // Get String representation media subtype (avc1, aac, tx3g, etc.)
                    NSString *subType = FourCCString(CMFormatDescriptionGetMediaSubType(desc));
                    // Format string as type/subType
                    [format appendFormat:@"%@/%@", type, subType];
                    // Comma separate if more than one format description
                    if (i < track.formatDescriptions.count - 1) {
                        [format appendString:@","];
                    }
                }
                NSLog(@"=>       : %@", format);
        }
#endif
        
                  // QuickTime video exportable with passthrough option (e.g. recorded with device)?
//                  [AVAssetExportSession determineCompatibilityOfExportPreset:AVAssetExportPresetPassthrough withAsset:avasset outputFileType:AVFileTypeMPEG4 completionHandler:^(BOOL compatible) {
//
                      NSString *exportPreset = nil;
//                      if (compatible) {
//                          // No reencoding required — will keep metadata (or not depending on user's settings)
//                          exportPreset = AVAssetExportPresetPassthrough;
//                      }
//                      else
//                      {
                          NSInteger maxPixels = lround(fmax(image.imageAsset.pixelWidth, image.imageAsset.pixelHeight));
                          NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avasset];
                          // This array never contains AVAssetExportPresetPassthrough,
                          // that is why we use determineCompatibilityOfExportPreset: before.
                          if ((maxPixels <= 640) && ([presets containsObject:AVAssetExportPreset640x480])) {
                              // Encode in 640x480 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset640x480;
                          }
                          else if ((maxPixels <= 960) && ([presets containsObject:AVAssetExportPreset960x540])) {
                              // Encode in 960x540 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset960x540;
                          }
                          else if ((maxPixels <= 1280) && ([presets containsObject:AVAssetExportPreset1280x720])) {
                              // Encode in 1280x720 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset1280x720;
                          }
                          else if ((maxPixels <= 1920) && ([presets containsObject:AVAssetExportPreset1920x1080])) {
                              // Encode in 1920x1080 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset1920x1080;
                          }
                          else if ((maxPixels <= 3840) && ([presets containsObject:AVAssetExportPreset1920x1080])) {
                              // Encode in 1920x1080 pixels — metadata will be lost
                              exportPreset = AVAssetExportPreset3840x2160;
                          }
                          else {
                              // Use highest quality for device
                              exportPreset = AVAssetExportPresetHighestQuality;
                          }
//                      }
                      
                      // Requests video with selected export preset…
                      @autoreleasepool {
                          [[PHImageManager defaultManager] requestExportSessionForVideo:image.imageAsset options:options
                         exportPreset:exportPreset
                        resultHandler:^(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info) {
#if defined(DEBUG_UPLOAD)
                                  NSLog(@"retrieveFullSizeAssetDataFromVideo returned info(%@)", info);
#endif
                                  // The handler needs to update the user interface => Dispatch to main thread
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      if ([info objectForKey:PHImageErrorKey]) {
                                          // Inform user and propose to cancel or continue
                                          NSError *error = [info valueForKey:PHImageErrorKey];
                                          [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                                                        andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_iCloud", @"Could not retrieve video. Error: %@"), [error localizedDescription]]
                                                       forRetrying:YES
                                                         withImage:image];
                                          return;
                                      }
                                  });
                            
                                  // Modifies video before upload to Piwigo server
                                  [self modifyVideo:image withAVAsset:avasset beforeExporting:exportSession];
//                                  [self modifyVideo:image beforeExporting:exportSession];
                              }
                           ];
                      }
                  }];
//              }];
}

-(void)modifyVideo:(ImageUpload *)image withAVAsset:(AVAsset *)originalVideo beforeExporting:(AVAssetExportSession *)exportSession
{
    // Strips private metadata if user requested it in Settings
    // Apple documentation: 'metadataItemFilterForSharing' removes user-identifying metadata items, such as location information and leaves only metadata releated to commerce or playback itself. For example: playback, copyright, and commercial-related metadata, such as a purchaser’s ID as set by a vendor of digital media, along with metadata either derivable from the media itself or necessary for its proper behavior are all left intact.
    [exportSession setMetadata:nil];
    if ([Model sharedInstance].stripGPSdataOnUpload) {
        [exportSession setMetadataItemFilter:[AVMetadataItemFilter metadataItemFilterForSharing]];
    } else {
        [exportSession setMetadataItemFilter:nil];
    }

    // Complete video range
    [exportSession setTimeRange:CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)];

    // Video formats — Always export video in MP4 format
    [exportSession setOutputFileType:AVFileTypeMPEG4];
    [exportSession setShouldOptimizeForNetworkUse:YES];
#if defined(DEBUG_UPLOAD)
    NSLog(@"Supported file types: %@", exportSession.supportedFileTypes);
    NSLog(@"Description: %@", exportSession.description);
#endif

    // Prepare MIME type
    NSString *mimeType = @"video/mp4";

    // Temporary filename and path
    [exportSession setOutputURL:[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[image.fileName stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp4"]]]];

    // Deletes temporary video file if exists (might be incomplete, etc.)
    [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

    // Export temporary video for upload
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([exportSession status] == AVAssetExportSessionStatusCompleted)
            {
                // Gets copy as NSData
                self.imageData = [[NSData dataWithContentsOfURL:exportSession.outputURL] copy];
                assert(self.imageData.length != 0);
#if defined(DEBUG_UPLOAD)
                AVAsset *videoAsset = [AVAsset assetWithURL:exportSession.outputURL];
                NSArray *assetMetadata = [videoAsset commonMetadata];
                NSLog(@"Export sucess :-)");
                NSLog(@"Video metadata: %@", assetMetadata);
#endif

                // Deletes temporary video file
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

                // Upload video with tags and properties
                [self uploadImage:image withMimeType:mimeType];
            }
            else if ([exportSession status] == AVAssetExportSessionStatusFailed)
            {
                // Deletes temporary video file if any
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];
                
                // Try to upload original file
                if ([originalVideo isKindOfClass:[AVURLAsset class]] &&
                    [[Model sharedInstance].uploadFileTypes containsString:[image.fileName pathExtension]]) {
                    AVURLAsset *originalFileURL = (AVURLAsset *)originalVideo;
                    self.imageData = [[NSData dataWithContentsOfURL:originalFileURL.URL] copy];
                    NSArray *assetMetadata = [originalVideo commonMetadata];

                    // Creates metadata without location data
                    NSMutableArray *newAssetMetadata = [NSMutableArray array];
                    for (AVMetadataItem *item in assetMetadata) {
                        if ([item.commonKey isEqualToString:AVMetadataCommonKeyLocation]){
#if defined(DEBUG_UPLOAD)
                            NSLog(@"Location found: %@", item.stringValue);
#endif
                        } else {
                            [newAssetMetadata addObject:item];
                        }
                    }
                    BOOL assetDoesNotContainGPSmetadata =
                        (newAssetMetadata.count == assetMetadata.count) || ([assetMetadata count] == 0);

                    if (self.imageData && ((![Model sharedInstance].stripGPSdataOnUpload) || ([Model sharedInstance].stripGPSdataOnUpload && assetDoesNotContainGPSmetadata))) {

                        // Upload video with tags and properties
                        
                        [self uploadImage:image withMimeType:mimeType];
                        return;
                    } else {
                        // No data — Inform user that it won't succeed
                        [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                                      andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_export", @"Sorry, the video could not be retrieved for the upload. Error: %@"), exportSession.error.localizedDescription]
                                     forRetrying:NO
                                       withImage:image];
                        return;
                    }
                }
            }
            else if ([exportSession status] == AVAssetExportSessionStatusCancelled)
            {
                // Deletes temporary video file
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

                // Inform user
                [self showErrorWithTitle:NSLocalizedString(@"uploadCancelled_title", @"Upload Cancelled")
                              andMessage:NSLocalizedString(@"videoUploadCancelled_message", @"The upload of the video has been cancelled.")
                             forRetrying:YES
                               withImage:image];
                return;
            }
            else    // Failed for unknown reason!
            {
                // Deletes temporary video files
                [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];

                // Inform user
                [self showErrorWithTitle:NSLocalizedString(@"videoUploadError_title", @"Video Upload Error")
                              andMessage:[NSString stringWithFormat:NSLocalizedString(@"videoUploadError_unknown", @"Sorry, the upload of the video has failed for an unknown error during the MP4 conversion. Error: %@"), exportSession.error.localizedDescription]
                             forRetrying:YES
                               withImage:image];
                return;
            }
        });
    }];
}

#if defined(DEBUG_UPLOAD)
static NSString * FourCCString(FourCharCode code) {
    NSString *result = [NSString stringWithFormat:@"%c%c%c%c",
                        (code >> 24) & 0xff,
                        (code >> 16) & 0xff,
                        (code >> 8) & 0xff,
                        code & 0xff];
    NSCharacterSet *characterSet = [NSCharacterSet whitespaceCharacterSet];
    return [result stringByTrimmingCharactersInSet:characterSet];
}
#endif

// The creation date is kept when copying the MOV video file and uploading it with MP4 extension in Piwigo
// However, it is replaced when exporting the file in Piwigo while the metadata is correct.
// With this method, the thumbnail is produced correctly

//-(void)retrieveFullSizeAssetDataFromVideo:(ImageUpload *)image withMimeType:(NSString *)mimeType  // Asynchronous
//{
//    // Case of a video…
//    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
//    // Requests the most recent version of the image asset
//    options.version = PHVideoRequestOptionsVersionCurrent;
//    // Requests the highest-quality video available, regardless of how much time it takes to load.
//    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
//    // Photos can download the requested video from iCloud.
//    options.networkAccessAllowed = YES;
//    // The block Photos calls periodically while downloading the video.
//    options.progressHandler = ^(double progress,NSError *error,BOOL* stop, NSDictionary* dict) {
//        NSLog(@"downloading Video from iCloud — progress %lf",progress);
//    };
//
//    // Requests video…
//    @autoreleasepool {
//        [[PHImageManager defaultManager] requestAVAssetForVideo:image.imageAsset options:options
//              resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
//#if defined(DEBUG_UPLOAD)
//                  NSLog(@"retrieveFullSizeAssetDataFromVideo returned info(%@)", info);
//#endif
//                  // Error encountered while retrieving asset?
//                  if ([info objectForKey:PHImageErrorKey]) {
//                      NSError *error = [info valueForKey:PHImageErrorKey];
//#if defined(DEBUG_UPLOAD)
//                      NSLog(@"=> Error : %@", error.description);
//#endif
//                  }
//
//                  // We don't accept degraded assets
//                  if ([[info valueForKey:PHImageResultIsDegradedKey] boolValue]) {
//                      // This is a degraded version, wait for the next one…
//                      return;
//                  }
//
//                  // Location of temporary video file
//                  NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:image.image]];
//
//                  // Deletes temporary file if exists already (might be incomplete, etc.)
//                  [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//
//                  // Writes to documents folder before uploading to Piwigo server
//                  if ([asset isKindOfClass:[AVURLAsset class]]) {
//
//                      // Simple video
//                      AVURLAsset *avurlasset = (AVURLAsset*) asset;
//                      NSLog(@"avurlasset=%@", avurlasset.URL.absoluteString);
//
//                      // Creates temporary video file and modify it as needed
//                      NSError *error;
//                      if ([[NSFileManager defaultManager] copyItemAtURL:avurlasset.URL toURL:fileURL error:&error]) {
//                          // Modifies video before upload to Piwigo server
//                          [self modifyVideo:image atURL:fileURL withMimeType:mimeType];
//                      } else {
//                          // Could not copy the video file!
//#if defined(DEBUG_UPLOAD)
//                          NSLog(@"=> Error : %@", error.description);
//#endif
//                      }
//                  } else if ([asset isKindOfClass:[AVComposition class]]) {
//
////                      NSURL *avurlasset = [NSURL fileURLWithPath:@"/var/mobile/Media/DCIM/105APPLE/IMG_5374.MOV"];
////                      NSLog(@"avurlasset=%@", avurlasset.absoluteString);
////
////                      // Creates temporary video file and modify it as needed
////                      NSError *error;
////                      if ([[NSFileManager defaultManager] copyItemAtURL:avurlasset toURL:fileURL error:&error]) {
////                          // Modifies video before upload to Piwigo server
////                          [self modifyVideo:image atURL:fileURL withMimeType:mimeType];
////                      } else {
////                          // Could not copy the video file!
////#if defined(DEBUG_UPLOAD)
////                          NSLog(@"=> Error : %@", error.description);
////#endif
////                      }
//
//                      // AVComposition object, e.g. a Slow-Motion video
//                      AVMutableComposition *avComp = [(AVComposition*) asset copy];
//
//                      // Export Slow-Mo as standard video
//                      AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avComp presetName:AVAssetExportPresetHighestQuality];
//                      [exportSession setOutputURL:fileURL];
//                      exportSession.outputFileType = AVFileTypeMPEG4;
////                      exportSession.outputFileType = AVFileTypeQuickTimeMovie;
//                      [exportSession setShouldOptimizeForNetworkUse:YES];
//                      [exportSession exportAsynchronouslyWithCompletionHandler:^{
//                          // Error ?
//                          if (exportSession.error) {
//                              NSLog(@"=> exportSession Status: %ld and Error: %@", (long)exportSession.status, exportSession.error.description);
//                              return;
//                          }
//
//                          // Modifies video before upload to Piwigo server
//                          [self modifyVideo:image atURL:exportSession.outputURL withMimeType:mimeType];
//                      }];
//                  }
//              }
//         ];
//    }
//}

//-(void)modifyVideo:(ImageUpload *)image atURL:(NSURL *)fileURL withMimeType:(NSString *)mimeType
//{
//    // Video and metadata from asset
//    __block NSData *assetData = nil;
//    AVAsset *videoAsset = [AVAsset assetWithURL:fileURL];
//    NSArray *assetMetadata = [videoAsset commonMetadata];
//
//    // Strips GPS data if user requested it in Settings
//    if (![Model sharedInstance].stripGPSdataOnUpload || ([assetMetadata count] == 0)) {
//
//        // Gets copy as NSData
//        assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
//        assert(assetData.length != 0);
//
//        // Deletes temporary video file
//        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//
//        // Upload video with tags and properties
//        [self uploadImage:image withData:assetData andMimeType:mimeType];
//    }
//    else
//    {
//        // Creates metadata without location data
//        NSMutableArray *newAssetMetadata = [NSMutableArray array];
//        for (AVMetadataItem *item in assetMetadata) {
//            if ([item.commonKey isEqualToString:AVMetadataCommonKeyLocation]){
//#if defined(DEBUG_UPLOAD)
//                NSLog(@"Location found: %@", item.stringValue);
//#endif
//            } else {
//                [newAssetMetadata addObject:item];
//            }
//        }
//
//        // Done if metadata did not contain location
//        if (newAssetMetadata.count == assetMetadata.count) {
//
//            // Gets copy as NSData
//            assetData = [[NSData dataWithContentsOfURL:fileURL] copy];
//            assert(assetData.length != 0);
//
//            // Deletes temporary video file
//            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//
//            // Upload video with tags and properties
//            [self uploadImage:image withData:assetData andMimeType:mimeType];
//        }
//        else if ([videoAsset isExportable]) {
//
//            // Export new asset from original asset
//            AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:videoAsset presetName:AVAssetExportPresetPassthrough];
//            NSLog(@"exportSession (before): %@", exportSession);
//            NSLog(@"Supported file types: %@", exportSession.supportedFileTypes);
//
//            // Filename is ("_" + name + ".mp4") in same directory
//            NSURL *newFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[@"_" stringByAppendingString:[image.image stringByDeletingPathExtension]] stringByAppendingPathExtension:@"mp4"]]];
//            exportSession.outputURL = newFileURL;
//            if ([exportSession.supportedFileTypes containsObject:AVFileTypeMPEG4]) {
//                exportSession.outputFileType = AVFileTypeMPEG4;
//            } else {
//                exportSession.outputFileType = AVFileTypeQuickTimeMovie;
//            }
//            exportSession.shouldOptimizeForNetworkUse = YES;
////            exportSession.fileLengthLimit ??
//
//            // Deletes temporary file if exists already (might be incomplete, etc.)
//            [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//            // Video range
//            CMTime start = kCMTimeZero;
//            CMTimeRange range = CMTimeRangeMake(start, [videoAsset duration]);
//            exportSession.timeRange = range;
//
//            // Updated metadata
//            exportSession.metadata = newAssetMetadata;
//
//            // Export video
//            [exportSession exportAsynchronouslyWithCompletionHandler:^{
//                if ([exportSession status] == AVAssetExportSessionStatusCompleted)
//                {
//#if defined(DEBUG_UPLOAD)
//                    NSLog(@"Export sucess…");
//#endif
//                    // Gets copy as NSData
//                    assetData = [[NSData dataWithContentsOfURL:newFileURL] copy];
//                    AVAsset *videoAsset = [AVAsset assetWithURL:newFileURL];
//                    NSArray *assetMetadata = [videoAsset commonMetadata];
//                    NSLog(@"Video metadata: %@", assetMetadata);
//                    assert(assetData.length != 0);
//
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                    // Upload video with tags and properties
//                    [self uploadImage:image withData:assetData andMimeType:mimeType];
//                }
//                else if ([exportSession status] == AVAssetExportSessionStatusFailed)
//                {
//#if defined(DEBUG_UPLOAD)
//                    NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
//#endif
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                }
//                else if ([exportSession status] == AVAssetExportSessionStatusCancelled)
//                {
//#if defined(DEBUG_UPLOAD)
//                    NSLog(@"Export canceled");
//#endif
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                }
//                else
//                {
//#if defined(DEBUG_UPLOAD)
//                    NSLog(@"Export ??");
//#endif
//                    // Deletes temporary video files
//                    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
//                    [[NSFileManager defaultManager] removeItemAtURL:newFileURL error:nil];
//
//                }
//            }];
//        }
//        else {
//            // Could not export a new video — What to do?
//        }
//    }
//}


#pragma mark - Upload image/video

//-(void)uploadImage:(ImageUpload *)image withMimeType:(NSString *)mimeType
//{
//    // Chek that the final image format will be accepted by the Piwigo server
//    if (![[Model sharedInstance].uploadFileTypes containsString:[[image.fileName pathExtension] lowercaseString]]) {
//        [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
//                      andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), NSLocalizedString(@"imageUploadError_destination", @"cannot create image destination")]
//                     forRetrying:YES
//                       withImage:image];
//        return;
//    }
//
//    // Append Tags
//    NSMutableArray *tagIds = [NSMutableArray new];
//    for(PiwigoTagData *tagData in image.tags)
//    {
//        [tagIds addObject:@(tagData.tagId)];
//    }
//
//    // Prepare properties for uploaded image/video (filename key is kPiwigoImagesUploadParamFileName)
//    __block NSDictionary *imageProperties = @{
//                                      kPiwigoImagesUploadParamFileName : image.fileName,
//                                      kPiwigoImagesUploadParamTitle : image.imageTitle,
//                                      kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(image.categoryToUploadTo)],
//                                      kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(image.privacyLevel)],
//                                      kPiwigoImagesUploadParamAuthor : image.author,
//                                      kPiwigoImagesUploadParamDescription : image.comment,
//                                      kPiwigoImagesUploadParamTags : [tagIds copy],
//                                      kPiwigoImagesUploadParamMimeType : mimeType
//                                      };
//    tagIds = nil;
//
//    // Release memory
//    imageProperties = nil;
//    self.imageData = nil;
//
//    NSLog(@"END");
//}

-(void)uploadImage:(ImageUpload *)image withMimeType:(NSString *)mimeType
{
    // Chek that the final image format will be accepted by the Piwigo server
    if (![[Model sharedInstance].uploadFileTypes containsString:[[image.fileName pathExtension] lowercaseString]]) {
        [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
                      andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), NSLocalizedString(@"imageUploadError_destination", @"cannot create image destination")]
                     forRetrying:YES
                       withImage:image];
        return;
    }
    
    // Prepare creation date
    NSString *creationDate = @"";
    if (image.creationDate != nil) {
        NSDateFormatter *dateFormat = [NSDateFormatter new];
        [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        creationDate = [dateFormat stringFromDate:image.creationDate];
    }

    // Append Tags
    NSMutableArray *tagIds = [NSMutableArray new];
    for(PiwigoTagData *tagData in image.tags)
    {
        [tagIds addObject:@(tagData.tagId)];
    }
    
    // Prepare properties for uploaded image/video (filename key is kPiwigoImagesUploadParamFileName)
    __block NSDictionary *imageProperties = @{
                                      kPiwigoImagesUploadParamFileName : image.fileName,
                                      kPiwigoImagesUploadParamCreationDate : creationDate,
                                      kPiwigoImagesUploadParamTitle : image.imageTitle,
                                      kPiwigoImagesUploadParamCategory : [NSString stringWithFormat:@"%@", @(image.categoryToUploadTo)],
                                      kPiwigoImagesUploadParamPrivacy : [NSString stringWithFormat:@"%@", @(image.privacyLevel)],
                                      kPiwigoImagesUploadParamAuthor : image.author,
                                      kPiwigoImagesUploadParamDescription : image.comment,
                                      kPiwigoImagesUploadParamTags : [tagIds copy],
                                      kPiwigoImagesUploadParamMimeType : mimeType
                                      };
    tagIds = nil;
    
    // Upload photo or video
    [UploadService uploadImage:self.imageData
               withInformation:imageProperties
                    onProgress:^(NSProgress *progress, NSInteger currentChunk, NSInteger totalChunks) {
                        ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
                        if (imageBeingUploaded.stopUpload) {
                            [progress cancel];
                        }
                        self.current = (NSInteger) progress.completedUnitCount;
                        self.total = (NSInteger) progress.totalUnitCount;
                        self.currentChunk = currentChunk;
                        self.totalChunks = totalChunks;
                        if([self.delegate respondsToSelector:@selector(imageProgress:onCurrent:forTotal:onChunk:forChunks:iCloudProgress:)])
                        {
                            [self.delegate imageProgress:image onCurrent:self.current forTotal:self.total onChunk:currentChunk forChunks:totalChunks iCloudProgress:self.iCloudProgress];
                        }
                    } OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {

                        if([[response objectForKey:@"stat"] isEqualToString:@"ok"])
                        {
                            // Consider image job done
                            self.onCurrentImageUpload++;
                        
                            // Get imageId
                            NSDictionary *imageResponse = [response objectForKey:@"result"];
                            NSInteger imageId = [[imageResponse objectForKey:@"image_id"] integerValue];
                        
                            // Set properties of uploaded image/video on Piwigo server and add it to cahe
                            [self setImage:image withInfo:imageProperties andId:imageId];

                            // The image must be moderated if the Community plugin is installed
                            if ([Model sharedInstance].usesCommunityPluginV29)
                            {
                                // Append image to list of images to moderate
                                self.uploadedImagesToBeModerated = [self.uploadedImagesToBeModerated stringByAppendingFormat:@"%ld,", (long)imageId];
                            }

                            // Release memory
                            imageProperties = nil;
                            self.imageData = nil;
                        
                            // Delete image from Photos library if requested
                            if ([Model sharedInstance].deleteImageAfterUpload &&
                                (image.imageAsset.sourceType != PHAssetSourceTypeCloudShared)) {
                                [self.imageDeleteQueue addObject:image.imageAsset];
                            }

                            dispatch_async(dispatch_get_main_queue(), ^{
                                // Remove image from queue and upload next one
                                [self uploadNextImageAndRemoveImageFromQueue:image withResponse:response];
                            });
                        }
                        else {
                            // Release memory
                            imageProperties = nil;
                            self.imageData = nil;

                            // Display Piwigo error
                            NSString *errorMsg = @"";
                            if ([response objectForKey:@"message"]) {
                                errorMsg = [response objectForKey:@"message"];
                            }
                            [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
                                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), errorMsg]
                                         forRetrying:YES
                                           withImage:image];
                        }
                        
                    } onFailure:^(NSURLSessionTask *task, NSError *error) {
                        // Release memory
                        imageProperties = nil;
                        self.imageData = nil;

                        // What should we do?
                        ImageUpload *imageBeingUploaded = [self.imageUploadQueue firstObject];
                        if (imageBeingUploaded.stopUpload) {
                            
                            // Upload was cancelled by user
                            self.maximumImagesForBatch--;
                            
                            // Remove image from queue and upload next one
                            [self uploadNextImageAndRemoveImageFromQueue:image withResponse:nil];
                        }
                        else
                        {
#if defined(DEBUG_UPLOAD)
                            NSLog(@"ERROR IMAGE UPLOAD: %@", error);
#endif
                            // Inform user and propose to cancel or continue
                            [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
                                          andMessage:[NSString stringWithFormat:NSLocalizedString(@"uploadError_message", @"Could not upload your image. Error: %@"), [error localizedDescription]]
                                         forRetrying:YES
                                           withImage:image];
                        }
                    }
     ];
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
                                            [self.imageNamesUploadQueue removeObject:[nextImage.fileName stringByDeletingPathExtension]];
                                        }
                                        
                                        // Tell user how many images have been uploaded
                                        if([self.delegate respondsToSelector:@selector(imageUploaded:placeInQueue:outOf:withResponse:)])
                                        {
                                            [self.delegate imageUploaded:image placeInQueue:self.onCurrentImageUpload outOf:self.maximumImagesForBatch withResponse:nil];
                                        }
                                        
                                        // Stop uploading
                                        self.isUploading = NO;
                                    }];
    
    // Should we propose to retry?
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
    }

    // Should we propose to upload the next image
    if (self.imageUploadQueue.count > 1) {
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
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Finish image upload

-(void)setImage:(ImageUpload *)image withInfo:(NSDictionary*)imageInfo andId:(NSInteger)imageId
{
        // Set properties of image on Piwigo server
        [ImageService setImageInfoForImageWithId:imageId
                                 withInformation:imageInfo
                                      onProgress:^(NSProgress *progress) {
                                           // progress
                                       } OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {

                           if([[response objectForKey:@"stat"] isEqualToString:@"ok"])
                           {
                               // Increment number of images in category
                               [[[CategoriesData sharedInstance] getCategoryById:image.categoryToUploadTo] incrementImageSizeByOne];
                           
                               // Read image/video information and update cache
                               [self addImageDataToCategoryCache:imageId];
                           }
                           else {
                               // Display Piwigo error in HUD
                               NSError *error = [NetworkHandler getPiwigoErrorFromResponse:response path:kPiwigoImageSetInfo andURLparams:nil];
                               [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
                                             andMessage:[error localizedDescription]
                                            forRetrying:NO
                                              withImage:image];
                           }
                       } onFailure:^(NSURLSessionTask *task, NSError *error) {
                           // Inform user and propose to cancel or continue
                            [self showErrorWithTitle:NSLocalizedString(@"uploadError_title", @"Upload Error")
                                          andMessage:[error localizedDescription]
                                         forRetrying:NO
                                           withImage:image];
}];
}

-(void)addImageDataToCategoryCache:(NSInteger)imageId
{
    // Read image information and update cache
    [ImageService getImageInfoById:imageId
                andAddImageToCache:YES
                  ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData)
    {
                          // Post to the app that the category data have been updated
//                          NSDictionary *userInfo = @{@"NoHUD" : @"YES", @"fromCache" : @"NO"};
//                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationGetCategoryData object:nil userInfo:userInfo];
                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil userInfo:nil];
                      } onFailure:^(NSURLSessionTask *task, NSError *error) {
                          //
                      }];
}


#pragma mark - Scale, crop, rotate, etc. image before upload

-(UIImage *)fixOrientationOfImage:(UIImage *)image {
    
    // No-op if the orientation is already correct
    if (image.imageOrientation == UIImageOrientationUp) return image;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (image.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, image.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (image.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, image.size.width, image.size.height,
                                             CGImageGetBitsPerComponent(image.CGImage), 0,
                                             CGImageGetColorSpace(image.CGImage),
                                             CGImageGetBitmapInfo(image.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (image.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,image.size.height,image.size.width), image.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,image.size.width,image.size.height), image.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

- (UIImage *)rotateImage:(UIImage *)imageIn andScaleItTo:(CGFloat)scaleRatio
{
    CGImageRef        imgRef    = imageIn.CGImage;
    CGFloat           width     = CGImageGetWidth(imgRef);
    CGFloat           height    = CGImageGetHeight(imgRef);
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect            bounds    = CGRectMake( 0, 0, width, height );
    bounds.size.width = width * scaleRatio;
    bounds.size.height = height * scaleRatio;
    
    CGSize             imageSize    = CGSizeMake( CGImageGetWidth(imgRef),         CGImageGetHeight(imgRef) );
    UIImageOrientation orient       = imageIn.imageOrientation;
    CGFloat            boundHeight;
    
    switch(orient)
    {
        case UIImageOrientationUp:                                        //EXIF = 1
            transform = CGAffineTransformIdentity;
            break;
            
        case UIImageOrientationUpMirrored:                                //EXIF = 2
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
            
        case UIImageOrientationDown:                                      //EXIF = 3
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationDownMirrored:                              //EXIF = 4
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
            
        case UIImageOrientationLeftMirrored:                              //EXIF = 5
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationLeft:                                      //EXIF = 6
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationRightMirrored:                             //EXIF = 7
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        case UIImageOrientationRight:                                     //EXIF = 8
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        default:
            [NSException raise: NSInternalInconsistencyException
                        format: @"Invalid image orientation"];
            
    }
    
    UIGraphicsBeginImageContext( bounds.size );
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if ( orient == UIImageOrientationRight || orient == UIImageOrientationLeft )
    {
        CGContextScaleCTM(context, -scaleRatio, scaleRatio);
        CGContextTranslateCTM(context, -height, 0);
    }
    else
    {
        CGContextScaleCTM(context, scaleRatio, -scaleRatio);
        CGContextTranslateCTM(context, 0, -height);
    }
    
    CGContextConcatCTM( context, transform );
    
    CGContextDrawImage( UIGraphicsGetCurrentContext(), CGRectMake( 0, 0, width, height ), imgRef );
    UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return( imageCopy );
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

//-(NSData*)writeMetadataIntoImageData:(NSData *)imageData metadata:(NSDictionary*)metadata
//{
//    // NOP if metadata == nil
//    if (!metadata) return imageData;
//
//    // Create an imagesourceref
//    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
//    if (!source) {
//#if defined(DEBUG_UPLOAD)
//        NSLog(@"Error: Could not create source");
//#endif
//    } else {
//        // Type of image (e.g., public.jpeg)
//        CFStringRef UTI = CGImageSourceGetType(source);
//
//        // Create a new data object and write the new image into it
//        NSMutableData *dest_data = [NSMutableData data];
//        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
//        if (!destination) {
//#if defined(DEBUG_UPLOAD)
//            NSLog(@"Error: Could not create image destination");
//#endif
//            CFRelease(source);
//        } else {
//            // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
//            CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
//            BOOL success = NO;
//            success = CGImageDestinationFinalize(destination);
//            if (!success) {
//#if defined(DEBUG_UPLOAD)
//                NSLog(@"Error: Could not create data from image destination");
//#endif
//                CFRelease(destination);
//                CFRelease(source);
//            } else {
//                CFRelease(destination);
//                CFRelease(source);
//                return [dest_data copy];
//            }
//        }
//    }
//    return imageData;
//}

@end
