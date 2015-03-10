//
//  SliderTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SliderTableViewCell.h"

@interface SliderTableViewCell()

@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *sliderCount;

@end

@implementation SliderTableViewCell

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		
		self.cacheType = [UILabel new];
		self.cacheType.translatesAutoresizingMaskIntoConstraints = NO;
		self.cacheType.font = [UIFont piwigoFontNormal];
		self.cacheType.textColor = [UIColor blackColor];
		self.cacheType.adjustsFontSizeToFitWidth = YES;
		self.cacheType.minimumScaleFactor = 0.5;
		self.cacheType.textAlignment = NSTextAlignmentRight;
		[self.contentView addSubview:self.cacheType];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.cacheType]];
		
		self.slider = [UISlider new];
		self.slider.translatesAutoresizingMaskIntoConstraints = NO;
		self.slider.minimumValue = 10;
		self.slider.maximumValue = 500;
		[self.slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
		[self.contentView addSubview:self.slider];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.slider]];
		
		self.sliderCount = [UILabel new];
		self.sliderCount.translatesAutoresizingMaskIntoConstraints = NO;
		self.sliderCount.textAlignment = NSTextAlignmentCenter;
		self.sliderCount.font = [UIFont piwigoFontNormal];
		self.sliderCount.textColor = [UIColor piwigoGray];
		self.sliderCount.text = @"20 MB";
		[self.contentView addSubview:self.sliderCount];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.sliderCount]];
		
		[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label(50)]-[count(80)]-[slider]-15-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"label" : self.cacheType,
																						   @"count" : self.sliderCount,
																						   @"slider" : self.slider}]];
	}
	return self;
}

-(void)sliderChanged
{
	NSInteger value = self.slider.value;
	NSInteger newValue = value - value % 10;
	
	self.slider.value = newValue;
	self.sliderCount.text = [NSString stringWithFormat:@"%@ MB", @(newValue)];
}

-(void)setSliderValue:(NSInteger)sliderValue
{
	self.slider.value = sliderValue;
	[self sliderChanged];
}

-(NSInteger)getCurrentSliderValue
{
	return self.slider.value;
}

@end
