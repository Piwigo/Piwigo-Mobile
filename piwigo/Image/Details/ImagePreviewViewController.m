//
//  ImagePreviewViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImagePreviewViewController.h"
#import "PiwigoImageData.h"
#import "ImageScrollView.h"
#import "ImageService.h"
#import "VideoView.h"
#import "NetworkHandler.h"

@interface ImagePreviewViewController () <AVAssetResourceLoaderDelegate>

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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:[PwgNotificationsObjc paletteChanged] object:nil];
    }
	return self;
}

#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color depends on the navigation bar visibility
    if (self.navigationController.navigationBarHidden)
        self.view.backgroundColor = [UIColor blackColor];
    else
        self.view.backgroundColor = [UIColor piwigoColorBackground];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoColorWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    self.navigationController.navigationBar.barStyle = AppVars.isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoColorOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoColorBackground];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoColorBackground];
    self.navigationBarHidden = YES;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    // Set colors, fonts, etc.
    [self applyColorPalette];    
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void)setImageScrollViewWithImageData:(PiwigoImageData*)imageData
{
    // Display "play" button if video
    self.scrollView.playImage.hidden = !(imageData.isVideo);

    // Thumbnail image should be available in cache
    NSString *thumbnailStr = [imageData getURLFromImageSizeType:(kPiwigoImageSize)AlbumVars.defaultThumbnailSize];
    NSURL *thumbnailURL = [NSURL URLWithString:thumbnailStr];
    UIImageView *thumb = [UIImageView new];
    thumb.image = [NetworkVarsObjc.thumbnailCache imageforRequest:[NSURLRequest requestWithURL:thumbnailURL] withAdditionalIdentifier:nil];
    self.scrollView.imageView.image = thumb.image ? thumb.image : [UIImage imageNamed:@"placeholderImage"];

    // Previewed image
    NSString *previewStr = [imageData getURLFromImageSizeType:(kPiwigoImageSize)ImageVars.shared.defaultImagePreviewSize];
    if (previewStr == nil) {
        // Image URL unknown => default to medium image size
        previewStr = [imageData getURLFromImageSizeType:kPiwigoImageSizeMedium];
        // After an upload, the server only returns the Square and Thumbnail sizes
        if (previewStr == nil) {
            previewStr = [imageData getURLFromImageSizeType:kPiwigoImageSizeThumb];
        }
    }
    NSURL *previewURL = [NSURL URLWithString:previewStr];
    __weak typeof(self) weakSelf = self;
    
//    NSLog(@"==> Start loading %@", previewURL.path);
    self.downloadTask = [NetworkVarsObjc.imagesSessionManager GET:previewURL.absoluteString
        parameters:nil headers:nil
        progress:^(NSProgress * _Nonnull progress) {
                    dispatch_async(dispatch_get_main_queue(),
                       ^(void){
                           // Update progress bar
                           if([weakSelf.imagePreviewDelegate respondsToSelector:@selector(downloadProgress:)])
                       {
                           [weakSelf.imagePreviewDelegate downloadProgress:progress.fractionCompleted];
                       }
                                });
                }
         success:^(NSURLSessionTask *task, UIImage *image) {
             if (image != nil) {
                 weakSelf.scrollView.imageView.image = image;
                 // Update progress bar
                 if([weakSelf.imagePreviewDelegate respondsToSelector:@selector(downloadProgress:)])
                 {
                     [weakSelf.imagePreviewDelegate downloadProgress:1.0];
                 }
                 // Hide progress bar
                 weakSelf.imageLoaded = YES;
                 // Store image in cache
                 NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:task.response data:UIImageJPEGRepresentation(image, 0.9)];
                 [NetworkVarsObjc.imageCache storeCachedResponse:cachedResponse forDataTask:weakSelf.downloadTask];
             }
             else {     // Keep thumbnail or placeholder if image could not be loaded
#if defined(DEBUG)
                 NSLog(@"setImageScrollViewWithImageData: loaded image is nil!");
#endif
             }
         }
         failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
             NSLog(@"setImageScrollViewWithImageData/GET Error: %@", error);
#endif
         }
     ];
    
    [self.downloadTask resume];
}

-(void)startVideoPlayerViewWithImageData:(PiwigoImageData*)imageData
{
    // Set URL
    NSURL *videoURL = [NSURL URLWithString:imageData.fullResPath];

    // AVURLAsset + Loader
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    AVAssetResourceLoader *loader = asset.resourceLoader;
    [loader setDelegate:self queue:dispatch_queue_create("Piwigo loader", nil)];
    
    // Load the asset's "playable" key
    [asset loadValuesAsynchronouslyForKeys:@[@"playable"] completionHandler:^{
        dispatch_async( dispatch_get_main_queue(),
           ^{
               /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
               NSError *error = nil;
               AVKeyValueStatus keyStatus = [asset statusOfValueForKey:@"playable" error:&error];
               switch (keyStatus) {
                   case AVKeyValueStatusLoaded:
                       // Sucessfully loaded, continue processing
                       [self playVideoAsset:asset];
                       break;
                   case AVKeyValueStatusFailed:
                       /* Display the error. */
                       [self assetFailedToPrepareForPlayback:error];
                       break;
                   case AVKeyValueStatusCancelled:
                       // Loading cancelled
                       break;
                   default:
                       // Handle all other cases
                       break;
               }
           });
    }];
}

-(void)playVideoAsset:(AVAsset *)asset
{
    // AVPlayer
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
    AVPlayer *videoPlayer = [AVPlayer playerWithPlayerItem:playerItem];    // Intialise video controller
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


-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:[error localizedDescription]
                         message:[error localizedFailureReason]
                  preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* dismissAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {
        }];
    
    [alert addAction:dismissAction];
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}


#pragma mark - AVAssetResourceLoader delegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader
shouldWaitForResponseToAuthenticationChallenge:(NSURLAuthenticationChallenge *)authenticationChallenge
{
    NSURLProtectionSpace *protectionSpace = authenticationChallenge.protectionSpace;
    if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        // Self-signed certificate…
        [authenticationChallenge.sender useCredential:[NSURLCredential credentialForTrust:authenticationChallenge.protectionSpace.serverTrust] forAuthenticationChallenge:authenticationChallenge];
        [authenticationChallenge.sender continueWithoutCredentialForAuthenticationChallenge:authenticationChallenge];
    }
    else if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic])
    {
        // HTTP basic authentification credentials
        NSString *user = NetworkVarsObjc.httpUsername;
        NSString *password = [KeychainUtilitiesObjc passwordForService:[NSString stringWithFormat:@"%@%@", NetworkVarsObjc.serverProtocol, NetworkVarsObjc.serverPath] account:user];
        [authenticationChallenge.sender useCredential:[NSURLCredential credentialWithUser:user password:password
                                                       persistence:NSURLCredentialPersistenceSynchronizable] forAuthenticationChallenge:authenticationChallenge];
        [authenticationChallenge.sender continueWithoutCredentialForAuthenticationChallenge:authenticationChallenge];
    }
    else { // Other type: username password, client trust...
        NSLog(@"Other type: username password, client trust...");
    }
    return YES;
}

@end
