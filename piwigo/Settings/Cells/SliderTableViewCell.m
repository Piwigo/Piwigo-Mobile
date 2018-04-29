//
//  SliderTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SliderTableViewCell.h"

@interface SliderTableViewCell()

@property (nonatomic, strong) UILabel *sliderCount;

@end

@implementation SliderTableViewCell

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoCellBackgroundColor];
		
		self.sliderName = [UILabel new];
		self.sliderName.translatesAutoresizingMaskIntoConstraints = NO;
		self.sliderName.font = [UIFont piwigoFontNormal];
		self.sliderName.textColor = [UIColor piwigoLeftLabelColor];
		self.sliderName.adjustsFontSizeToFitWidth = NO;
		[self.contentView addSubview:self.sliderName];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.sliderName]];
		
		self.slider = [UISlider new];
		self.slider.translatesAutoresizingMaskIntoConstraints = NO;
		self.slider.minimumValue = 10;
		self.slider.maximumValue = 200;
        self.slider.tintColor = [UIColor piwigoOrange];
        self.slider.thumbTintColor = [UIColor piwigoThumbColor];
		[self.slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
		[self.contentView addSubview:self.slider];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.slider]];
		
		self.sliderCount = [UILabel new];
		self.sliderCount.translatesAutoresizingMaskIntoConstraints = NO;
		self.sliderCount.textAlignment = NSTextAlignmentRight;
		self.sliderCount.font = [UIFont piwigoFontNormal];
		self.sliderCount.textColor = [UIColor piwigoRightLabelColor];
		self.sliderCount.adjustsFontSizeToFitWidth = NO;
		[self.contentView addSubview:self.sliderCount];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.sliderCount]];
		
		if (@available(iOS 11, *)) {
            [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[label]-[slider]-[count]-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"label" : self.sliderName,
                                                                                           @"slider" : self.slider,
																						   @"count" : self.sliderCount
																						   }]];
        } else {
            [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label]-[slider]-[count]-15-|"
                                                                                     options:kNilOptions
                                                                                     metrics:nil
                                                                                       views:@{@"label" : self.sliderName,
                                                                                               @"slider" : self.slider,
                                                                                               @"count" : self.sliderCount
                                                                                               }]];
        }
	}
	return self;
}

-(void)sliderChanged
{
    NSInteger ref = (int)roundf(self.slider.minimumValue);
    NSInteger value = self.slider.value;
    NSInteger newValue = value - ((value - ref) % self.incrementSliderBy);
    self.slider.value = newValue;
	self.sliderCount.text = [NSString stringWithFormat:@"%@%@%@", self.sliderCountPrefix, @(newValue), self.sliderCountSuffix];
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
