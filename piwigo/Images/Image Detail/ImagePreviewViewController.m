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
#import "Model.h"
#import "NetworkHandler.h"
#import "KeychainAccess.h"

@interface ImagePreviewViewController ()


@end

@implementation ImagePreviewViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.scrollView = [ImageScrollView new];
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
    
    // Stop playing video if needed
    if ([self.scrollView.player playbackState]) {
        [self.scrollView.player stop];
    }
}

-(void)setImageWithImageData:(PiwigoImageData*)imageData
{
	if(imageData.isVideo)
	{
		[self.scrollView setupPlayerWithURL:imageData.fullResPath];
		return;
	}
    
    UIImageView *thumb = [UIImageView new];
    NSString *URLRequest = [NetworkHandler getURLWithPath:imageData.ThumbPath asPiwigoRequest:NO withURLParams:nil];
    [thumb setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];

	NSString *URLString = [imageData getURLFromImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize];
    URLRequest = [NetworkHandler getURLWithPath:URLString asPiwigoRequest:NO withURLParams:nil];
    NSURL *request = [NSURL URLWithString:URLRequest];
    
	__weak typeof(self) weakSelf = self;

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFImageResponseSerializer serializer];
    
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    [manager setSecurityPolicy:policy];
    
    // Manage servers performing HTTP Authentication
    NSString *user = [KeychainAccess getLoginUser];
    if ((user != nil) && ([user length] > 0)) {
        NSString *password = [KeychainAccess getLoginPassword];
        [manager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
            // Supply requested credentials
            *credential = [NSURLCredential credentialWithUser:user
                                                     password:password
                                                  persistence:NSURLCredentialPersistenceForSession];
            return NSURLSessionAuthChallengeUseCredential;
        }];
    }
    
    weakSelf.scrollView.imageView.image = thumb.image ? thumb.image : [UIImage imageNamed:@"placeholderImage"];
    
    [manager GET:request.absoluteString
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
             weakSelf.imageLoaded = YES;
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

@end
