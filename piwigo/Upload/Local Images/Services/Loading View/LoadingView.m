//
//  LoadingView.m
//  piwigo
//
//  Created by Spencer Baker on 12/30/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "LoadingView.h"
#import "UICountingLabel.h"

@interface LoadingView()

@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIImageView *checkMark;

@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;
@end

@implementation LoadingView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.translatesAutoresizingMaskIntoConstraints = NO;
		self.backgroundColor = [UIColor grayColor];
		self.alpha = 0.6;
		self.layer.cornerRadius = 10;
		self.hidden = YES;
		
		self.textLabel = [UILabel new];
		self.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.textLabel.font = [UIFont systemFontOfSize:19];
		self.textLabel.textColor = [UIColor whiteColor];
		self.textLabel.text = NSLocalizedString(@"loadingHUD_label", @"Loading…");
		[self addSubview:self.textLabel];
		
		self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:self.spinner];
		
		UIImage *checkMarkImg = [UIImage imageNamed:@"checkMark"];
		checkMarkImg = [checkMarkImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.checkMark = [[UIImageView alloc] initWithImage:checkMarkImg];
		self.checkMark.translatesAutoresizingMaskIntoConstraints = NO;
		self.checkMark.tintColor = [UIColor greenColor];
		[self addSubview:self.checkMark];
		
		self.progressLabel = [UICountingLabel new];
		self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.progressLabel.font = [UIFont systemFontOfSize:15];
		self.progressLabel.textColor = [UIColor whiteColor];
		[self addSubview:self.progressLabel];
		
		[self setupConstraints];
	}
	return self;
}

-(void)setupConstraints
{
	NSDictionary *loadingViews = @{
								   @"label" : self.textLabel,
								   @"spinner" : self.spinner,
								   @"progress" : self.progressLabel
								   };
	
	self.heightConstraint = [NSLayoutConstraint constraintView:self toHeight:150];
	[self addConstraint:self.heightConstraint];
	[self addConstraint:[NSLayoutConstraint constraintWithItem:self
													 attribute:NSLayoutAttributeLeft
													 relatedBy:NSLayoutRelationEqual
														toItem:self.textLabel
													 attribute:NSLayoutAttributeLeft
													multiplier:1.0
													  constant:-10]];
	[self addConstraint:[NSLayoutConstraint constraintWithItem:self
													 attribute:NSLayoutAttributeRight
													 relatedBy:NSLayoutRelationEqual
														toItem:self.textLabel
													 attribute:NSLayoutAttributeRight
													multiplier:1.0
													  constant:10]];
	[self addConstraint:[NSLayoutConstraint constraintWithItem:self
													 attribute:NSLayoutAttributeWidth
													 relatedBy:NSLayoutRelationGreaterThanOrEqual
														toItem:self.checkMark
													 attribute:NSLayoutAttributeWidth
													multiplier:1.0
													  constant:10]];
	
	[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-10-[label]-20-[spinner]-20-[progress]"
																			 options:kNilOptions
																			 metrics:nil
																			   views:loadingViews]];
	[self addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.textLabel]];
	[self addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.spinner]];
	[self addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.progressLabel]];
	
	[self addConstraints:[NSLayoutConstraint constraintViewToSameLocation:self.checkMark asView:self.spinner]];
}

-(void)hideLoadingWithLabel:(NSString*)text showCheckMark:(BOOL)show withDelay:(CGFloat)delay
{
	self.textLabel.text = text;
	
	__weak typeof(self) weakSelf = self;
	if(show)
	{
		[UIView animateWithDuration:0.3 animations:^{
			weakSelf.checkMark.alpha = 1;
			weakSelf.spinner.alpha = 0;
		} completion:^(BOOL finished) {
			[weakSelf.spinner stopAnimating];
		}];
	}
	else [self.spinner stopAnimating];
	
	[UIView animateWithDuration:0.3 animations:^{
		self.heightConstraint.constant = 100;
		self.progressLabel.alpha = 0;
	}];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[UIView animateWithDuration:0.3 animations:^{
			weakSelf.alpha = 0;
		} completion:^(BOOL finished) {
			weakSelf.hidden = YES;
			[weakSelf removeFromSuperview];
		}];
	});
}

-(void)showLoadingWithLabel:(NSString*)text  andProgressLabel:(NSString*)progressText
{
	self.textLabel.text = text;
	[self setProgressLabelText:progressText];
	
	__weak typeof(self) weakSelf = self;
	[self.spinner startAnimating];
	self.alpha = 0;
	self.checkMark.alpha = 0;
	self.hidden = NO;
	[UIView animateWithDuration:0.3 animations:^{
		weakSelf.alpha = 1;
	}];
}

-(void)setProgressLabelText:(NSString*)text
{
	self.progressLabel.text = text;
}

@end
