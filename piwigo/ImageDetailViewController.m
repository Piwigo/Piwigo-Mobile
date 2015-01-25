//
//  ImageDetailViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageDetailViewController.h"
#import "PiwigoImageData.h"

@interface ImageDetailViewController ()

@property (nonatomic, strong) UIImageView *image;
@property (nonatomic, strong) UIProgressView *progressBar;

@end

@implementation ImageDetailViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor blackColor];
		
		self.image = [UIImageView new];
		self.image.translatesAutoresizingMaskIntoConstraints = NO;
		self.image.contentMode = UIViewContentModeScaleAspectFit;
		[self.view addSubview:self.image];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.image]];
		
		self.progressBar = [UIProgressView new];
		self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
		self.progressBar.hidden = YES;
		self.progressBar.tintColor = [UIColor piwigoOrange];
		[self.view addSubview:self.progressBar];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.progressBar]];
		[self.view addConstraint:[NSLayoutConstraint constrainViewFromTop:self.progressBar amount:64]];
		[self.progressBar addConstraint:[NSLayoutConstraint constrainViewToHeight:self.progressBar height:10]];
		
	}
	return self;
}

-(void)setupWithImageData:(PiwigoImageData*)imageData andPlaceHolderImage:(UIImage*)placeHolder
{
	self.title = imageData.name;
	
	__weak typeof(self) weakSelf = self;
	[self.image setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:imageData.mediumPath]]
					  placeholderImage:placeHolder
							   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								   weakSelf.image.image = image;
							   } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
								   
							   }];
	
	[self.image setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
		weakSelf.progressBar.hidden = NO;
		CGFloat percent = (CGFloat)totalBytesRead / totalBytesExpectedToRead;
		if(percent == 1) {
			weakSelf.progressBar.hidden = YES;
		} else {
			[weakSelf.progressBar setProgress:percent animated:YES];
		}
	}];
}

@end
