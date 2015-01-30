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

@property (nonatomic, assign) NSInteger currentImageIndex;

@end

@implementation ImageDetailViewController

-(instancetype)initWithImageIndex:(NSInteger)imageIndex
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor blackColor];
		self.currentImageIndex = imageIndex;
		
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
		
		UISwipeGestureRecognizer *rightSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight)];
		rightSwipe.direction = UISwipeGestureRecognizerDirectionRight;
		[self.view addGestureRecognizer:rightSwipe];
		
		UISwipeGestureRecognizer *leftSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft)];
		leftSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
		[self.view addGestureRecognizer:leftSwipe];
		
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

-(void)swipeRight
{
	
}

-(void)swipeLeft
{
	
}

@end
