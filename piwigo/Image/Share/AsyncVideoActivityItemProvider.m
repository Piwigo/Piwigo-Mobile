//
//  AsyncVideoActivityItemProvider.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Photos/Photos.h>

#import "AsyncVideoActivityItemProvider.h"
#import "ImageDetailViewController.h"
#import "ImageService.h"
#import "Model.h"

//#ifndef DEBUG_SHARE
//#define DEBUG_SHARE
//#endif

NSString * const kPiwigoNotificationDidShareVideo = @"kPiwigoNotificationDidShareVideo";
NSString * const kPiwigoNotificationCancelDownloadVideo = @"kPiwigoNotificationCancelDownloadVideo";

@interface AsyncVideoActivityItemProvider ()

@property (nonatomic, strong) PiwigoImageData* imageData;       // Image data
@property (nonatomic, strong) NSURLSessionDownloadTask *task;   // Download task
@property (nonatomic, strong) NSURL *imageFilePath;             // Image file path
@property (nonatomic, strong) NSString *alertTitle;             // Used if task cancels or fails
@property (nonatomic, strong) NSString *alertMessage;           // Used if task cancels or fails

@end

@implementation AsyncVideoActivityItemProvider

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
        [self.delegate imageActivityItemProviderPreprocessingDidBegin:self withTitle:NSLocalizedString(@"downloadingVideo", @"Downloading Video")];
    });
    
    // Register image share methods to perform on completion
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishSharingVideo) name:kPiwigoNotificationDidShareVideo object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelDownloadVideoTask) name:kPiwigoNotificationCancelDownloadVideo object:nil];
    
    // Determine the URL request and filename of the image file
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:self.imageData.fullResPath]];
    
    // Do we have the video in cache?
    self.imageFilePath = nil;
    NSData *cachedImageData = [[[Model sharedInstance].imageCache cachedResponseForRequest:urlRequest] data];
    if ((cachedImageData == nil) || (cachedImageData.bytes == 0)) {
        // Download video synchronously
        [self downloadSynchronouslyVideoWithUrlRequest:urlRequest];
    } else {
        // Video already in cache
        NSURL *tempDirectoryUrl = [NSURL fileURLWithPath:NSTemporaryDirectory()];
        self.imageFilePath = [tempDirectoryUrl URLByAppendingPathComponent:self.imageData.fileName];
    }
    
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
    
    // Notify the delegate on the main thread to show how it makes progress.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:1.0];
    });
    
    // Notify the delegate on the main thread that the processing has finished.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate imageActivityItemProviderPreprocessingDidEnd:self withImageId:self.imageData.imageId];
    });
    
    // Shared files w/ or w/o private metadata are saved in the /tmp directory and will be deleted:
    // - by the app if the user kills it
    // - by the system after a certain amount of time
    return self.imageFilePath;
}

-(void)downloadSynchronouslyVideoWithUrlRequest:(NSURLRequest*)urlRequest
{
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    self.task = [ImageService downloadVideo:self.imageData
                             withUrlRequest:urlRequest
                                 onProgress:^(NSProgress *progress) {
                                     // Notify the delegate on the main thread to show how it makes progress.
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         [self.delegate imageActivityItemProvider:self preprocessingProgressDidUpdate:(0.95 * progress.fractionCompleted)];
                                     });
                                 }
                          completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                              // Any error ?
                              if (error.code) {
                                  // Failed
                                  self.alertTitle = NSLocalizedString(@"downloadImageFail_title", @"Download Fail");
                                  self.alertMessage = [NSString stringWithFormat:NSLocalizedString(@"downloadVideoFail_message", @"Failed to download video!\n%@"), [error localizedDescription]];
                                  dispatch_semaphore_signal(sema);
                              }
                              else {
                                  // Cache video
                                  NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:[NSData dataWithContentsOfURL:filePath]];
                                  [[Model sharedInstance].imageCache storeCachedResponse:cachedResponse
                                                                              forRequest:urlRequest];

                                  // Retrieve image from file
                                  self.imageFilePath = filePath;
                                  dispatch_semaphore_signal(sema);
                              }
                          }
                 ];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    sema = nil;
}

-(void)cancelDownloadVideoTask
{
    // Cancel image file download
    [self.task cancel];
}

-(void)didFinishSharingVideo
{
    // Remove image share observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationDidShareVideo object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationCancelDownloadVideo object:nil];
    
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
