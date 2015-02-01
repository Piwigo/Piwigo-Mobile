//
//  ImageDownloadView.m
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageDownloadView.h"
#import "ImageDownloadingProgressView.h"

@interface ImageDownloadView()

@property (nonatomic, strong) UIView *modal;
@property (nonatomic, strong) ImageDownloadingProgressView *imageProgress;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *percentLabel;

@end

@implementation ImageDownloadView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		
		self.modal = [UIView new];
		self.modal.translatesAutoresizingMaskIntoConstraints = NO;
		self.modal.backgroundColor = [UIColor piwigoWhiteCream];
		self.modal.layer.cornerRadius = 20;
		[self addSubview:self.modal];
		[self addConstraints:[NSLayoutConstraint constraintViewToCenter:self.modal]];
		[self addConstraints:[NSLayoutConstraint constrainViewToSize:self.modal size:CGSizeMake(200, 150)]];
		
		
		self.statusLabel = [UILabel new];
		self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.statusLabel.text = @"Downloading Image";
		self.statusLabel.font = [UIFont piwigoFontNormal];
		self.statusLabel.font = [self.statusLabel.font fontWithSize:18];
		self.statusLabel.textColor = [UIColor piwigoGray];
		[self.modal addSubview:self.statusLabel];
		[self.modal addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.statusLabel]];
		[self.modal addConstraint:[NSLayoutConstraint constrainViewFromTop:self.statusLabel amount:10]];
		
		self.percentLabel = [UILabel new];
		self.percentLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.percentLabel.text = @"0 %";
		self.percentLabel.font = [UIFont piwigoFontNormal];
		self.percentLabel.font = [self.percentLabel.font fontWithSize:15];
		self.percentLabel.textColor = [UIColor piwigoGray];
		[self.modal addSubview:self.percentLabel];
		[self.modal addConstraint:[NSLayoutConstraint constraintHorizontalCenterView:self.percentLabel]];
		[self.modal addConstraint:[NSLayoutConstraint constrainViewFromBottom:self.percentLabel amount:10]];
		
		self.imageProgress = [ImageDownloadingProgressView new];
		self.imageProgress.translatesAutoresizingMaskIntoConstraints = NO;
		[self.modal addSubview:self.imageProgress];
		[self.modal addConstraints:[NSLayoutConstraint constraintViewToCenter:self.imageProgress]];
	}
	return self;
}

-(void)setDownloadImage:(UIImage *)downloadImage
{
	self.imageProgress.image = downloadImage;
}

-(void)setPercentDownloaded:(CGFloat)percentDownloaded
{
	self.imageProgress.percent = percentDownloaded;
	NSInteger percent = percentDownloaded * 100;
	if(percent == 100) {
		self.percentLabel.text = @"Complete";
	} else {
		self.percentLabel.text = [NSString stringWithFormat:@"%@ %%", @(percent)];
	}
}

@end
