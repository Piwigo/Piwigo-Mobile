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
		
		
	}
	return self;
}

-(void)setImageData:(PiwigoImageData*)imageData
{
	_imageData = imageData;
	
	__weak typeof(self) weakSelf = self;
	[self.image setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:imageData.mediumPath]]
					  placeholderImage:nil
							   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
								   weakSelf.image.image = image;
							   } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
								   
							   }];
}

@end
