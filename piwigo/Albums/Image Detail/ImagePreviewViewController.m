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

-(void)setImageWithImageData:(PiwigoImageData*)imageData
{
	if(imageData.isVideo)
	{
		[self.scrollView setupPlayerWithURL:imageData.fullResPath];
		return;
	}
    
    UIImageView *thumb = [UIImageView new];
    NSString *URLRequest = [NetworkHandler getURLWithPath:[imageData.ThumbPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] asPiwigoRequest:NO withURLParams:nil];
    [thumb setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
//	UIImage *thumb = [[UIImageView sharedImageCache] cachedImageForRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[imageData.thumbPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]];
	
	NSString *URLString = [imageData getURLFromImageSizeType:(kPiwigoImageSize)[Model sharedInstance].defaultImagePreviewSize];
    URLRequest = [NetworkHandler getURLWithPath:URLString asPiwigoRequest:NO withURLParams:nil];
    NSURL *request = [NSURL URLWithString:[URLRequest stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
	__weak typeof(self) weakSelf = self;

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFImageResponseSerializer serializer];
    
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
