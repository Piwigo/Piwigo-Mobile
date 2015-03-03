//
//  UploadHeaderCollectionReusableView.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SortHeaderCollectionReusableView.h"

@interface SortHeaderCollectionReusableView()

@end

@implementation SortHeaderCollectionReusableView

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		
		UILabel *sortLabel = [UILabel new];
		sortLabel.translatesAutoresizingMaskIntoConstraints = NO;
		sortLabel.text = @"Sort by";	// @TODO: Localize this!
		sortLabel.font = [UIFont piwigoFontNormal];
		[self addSubview:sortLabel];
		[self addConstraint:[NSLayoutConstraint constraintVerticalCenterView:sortLabel]];
		[self addConstraint:[NSLayoutConstraint constrainViewFromLeft:sortLabel amount:15]];
		
		UIImageView *disclosure = [UIImageView new];
		disclosure.translatesAutoresizingMaskIntoConstraints = NO;
		UIImage *disclosureImg = [[UIImage imageNamed:@"cellDisclosure"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		disclosure.image = disclosureImg;
		disclosure.tintColor = [UIColor piwigoGrayLight];
		[self addSubview:disclosure];
		[self addConstraints:[NSLayoutConstraint constrainViewToSize:disclosure size:CGSizeMake(30, 30)]];
		[self addConstraint:[NSLayoutConstraint constraintVerticalCenterView:disclosure]];
		
		self.currentSortLabel = [UILabel new];
		self.currentSortLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.currentSortLabel.text = @"Name";
		self.currentSortLabel.font = [UIFont piwigoFontNormal];
		self.currentSortLabel.textColor = [UIColor piwigoGrayLight];
		[self addSubview:self.currentSortLabel];
		[self addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.currentSortLabel]];

		[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[label]-5-[disclosure]-5-|"
																	 options:kNilOptions
																	 metrics:nil
																	   views:@{@"disclosure" : disclosure,
																			   @"label" : self.currentSortLabel}]];
		
	}
	return self;
}

@end
