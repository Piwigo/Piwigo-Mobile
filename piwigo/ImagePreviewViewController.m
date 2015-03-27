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
	
	UIImage *thumb = [[UIImageView sharedImageCache] cachedImageForRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[imageData.thumbPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]];
	
	__weak typeof(self) weakSelf = self;
	[self.scrollView.imageView setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[imageData.mediumPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]
									 placeholderImage:thumb ? thumb : [UIImage imageNamed:@"placeholder"]
							   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								   weakSelf.scrollView.imageView.image = image;
								   weakSelf.imageLoaded = YES;
							   } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
								   
							   }];

	[self.scrollView.imageView setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
		CGFloat percent = (CGFloat)totalBytesRead / totalBytesExpectedToRead;
		if([weakSelf.imagePreviewDelegate respondsToSelector:@selector(downloadProgress:)])
		{
			[weakSelf.imagePreviewDelegate downloadProgress:percent];
		}
		if(percent == 1)
		{
			weakSelf.imageLoaded = YES;
		}
	}];
}

@end
