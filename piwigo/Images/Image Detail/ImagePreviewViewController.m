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
		self.scrollView = [ImageScrollView new];
        self.videoView = [VideoView new];
		self.view = self.scrollView;
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationBarHidden = YES;
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
    NSURL *thumbnailURL = [NSURL URLWithString:[NetworkHandler getURLWithPath:thumbnailStr asPiwigoRequest:NO withURLParams:nil]];
    UIImageView *thumb = [UIImageView new];
    [thumb setImageWithURL:thumbnailURL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
    
    // Previewed image
    NSString *previewStr = [imageData getURLFromImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize];
    NSURL *previewURL = [NSURL URLWithString:[NetworkHandler getURLWithPath:previewStr asPiwigoRequest:NO withURLParams:nil]];
    __weak typeof(self) weakSelf = self;
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFImageResponseSerializer serializer];
    
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    [manager setSecurityPolicy:policy];
    
    // Manage servers performing HTTP Basic Access Authentication
    [manager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
        
        // HTTP basic authentification credentials
        NSString *user = [Model sharedInstance].HttpUsername;
        NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
        
        // Supply requested credentials if not provided yet
        if (challenge.previousFailureCount == 0) {
            // Trying HTTP credentials…
            *credential = [NSURLCredential credentialWithUser:user
                                                     password:password
                                                  persistence:NSURLCredentialPersistenceForSession];
            return NSURLSessionAuthChallengeUseCredential;
        } else {
            // HTTP credentials refused!
            return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }];
    
    weakSelf.scrollView.imageView.image = thumb.image ? thumb.image : [UIImage imageNamed:@"placeholderImage"];
    
    [manager GET:previewURL.absoluteString
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
             weakSelf.imageLoaded = YES;                        // Hide progress bar
             [manager invalidateSessionCancelingTasks:YES];
         }
         failure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
             NSLog(@"ImageDetail/GET Error: %@", error);
#endif
             [manager invalidateSessionCancelingTasks:YES];
         }
     ];
}

-(void)startVideoPlayerViewWithImageData:(PiwigoImageData*)imageData
{
    // Set URL
    NSString *videoStr = [NetworkHandler getURLWithPath:imageData.fullResPath asPiwigoRequest:NO withURLParams:nil];
    NSURL *videoURL = [NSURL URLWithString:[NetworkHandler getURLWithPath:videoStr asPiwigoRequest:NO withURLParams:nil]];

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
