//
//  ImagePreviewViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "ImagePreviewViewController.h"
#import "PiwigoImageData.h"
#import "ImageScrollView.h"
#import "VideoView.h"
#import "Model.h"
#import "NetworkHandler.h"
#import "SAMKeychain.h"

@interface ImagePreviewViewController ()

@end

@implementation ImagePreviewViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
        // Image
        self.scrollView = [ImageScrollView new];
        self.view = self.scrollView;

        // Video
        self.videoView = [VideoView new];

        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
    }
	return self;
}

#pragma mark - View Lifecycle

-(void)paletteChanged
{
    // Background color depends on the navigation bar visibility
    if (self.navigationController.navigationBarHidden)
        self.view.backgroundColor = [UIColor blackColor];
    else
        self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar appearence
    self.navigationBarHidden = YES;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    // Set colors, fonts, etc.
    [self paletteChanged];    
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void)setImageScrollViewWithImageData:(PiwigoImageData*)imageData
{
    // Display "play" button if video
    self.scrollView.playImage.hidden = !(imageData.isVideo);

    // Thumbnail image may be used as placeholder image
    NSString *thumbnailStr = [imageData getURLFromImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultThumbnailSize];
    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailStr];
    UIImageView *thumb = [UIImageView new];
    [thumb setImageWithURL:thumbnailURL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
    
    // Previewed image
    NSString *previewStr = [imageData getURLFromImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize];
    if (previewStr == nil) {
        // Image URL unknown => default to medium image size
        previewStr = [imageData getURLFromImageSizeType:kPiwigoImageSizeMedium];
    }
    NSURL *previewURL = [NSURL URLWithString:previewStr];
    __weak typeof(self) weakSelf = self;
    
    self.scrollView.imageView.image = thumb.image ? thumb.image : [UIImage imageNamed:@"placeholderImage"];

    [[Model sharedInstance].imagesSessionManager GET:previewURL.absoluteString
      parameters:nil
        progress:^(NSProgress *progress) {
            dispatch_async(dispatch_get_main_queue(),
                           ^(void){if([weakSelf.imagePreviewDelegate respondsToSelector:@selector(downloadProgress:)])
                           {
                               [weakSelf.imagePreviewDelegate downloadProgress:progress.fractionCompleted];
                           }
                               if(progress.fractionCompleted == 1)
                               {
                                   weakSelf.imageLoaded = YES;
                               }
                           });
        }
         success:^(NSURLSessionTask *task, UIImage *image) {
             weakSelf.scrollView.imageView.image = image;
             weakSelf.imageLoaded = YES;                      // Hide progress bar
         }
         failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
             NSLog(@"ImageDetail/GET Error: %@", error);
#endif
         }
     ];
}

-(void)startVideoPlayerViewWithImageData:(PiwigoImageData*)imageData
{
    // Set URL
    NSURL *videoURL = [NSURL URLWithString:imageData.fullResPath];

    // Intialise video controller
    AVPlayer *videoPlayer = [AVPlayer playerWithURL:videoURL];
    AVPlayerViewController *playerController = [[AVPlayerViewController alloc] init];
    playerController.player = videoPlayer;
    playerController.videoGravity = AVLayerVideoGravityResizeAspect;
    
    // Playback controls
    playerController.showsPlaybackControls = YES;
//    [self.videoPlayer addObserver:self.imageView forKeyPath:@"rate" options:0 context:nil];
    
    // Start playing automatically…
    [playerController.player play];
    
    [self.videoView addSubview:playerController.view];
    playerController.view.frame = self.videoView.bounds;

    // Present the video
    UIViewController *currentViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (currentViewController.presentedViewController)
    {
        currentViewController = currentViewController.presentedViewController;
    }
    [currentViewController presentViewController:playerController animated:YES completion:nil];
}

@end
