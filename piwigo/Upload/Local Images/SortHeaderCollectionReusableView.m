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
		self.backgroundColor = [UIColor piwigoWhiteCream];
		
		UILabel *sortLabel = [UILabel new];
		sortLabel.translatesAutoresizingMaskIntoConstraints = NO;
		sortLabel.text = NSLocalizedString(@"sortBy", @"Sort by");
		sortLabel.font = [UIFont piwigoFontNormal];
        sortLabel.textColor = [UIColor piwigoGray];
		sortLabel.minimumScaleFactor = 0.5;
		sortLabel.adjustsFontSizeToFitWidth = YES;
		[self addSubview:sortLabel];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:sortLabel]];
		
		UIImageView *disclosure = [UIImageView new];
		disclosure.translatesAutoresizingMaskIntoConstraints = NO;
		UIImage *disclosureImg = [[UIImage imageNamed:@"cellDisclosure"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		disclosure.image = disclosureImg;
		disclosure.tintColor = [UIColor piwigoGrayLight];
		[self addSubview:disclosure];
		[self addConstraints:[NSLayoutConstraint constraintView:disclosure toSize:CGSizeMake(30, 30)]];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:disclosure]];
		
		self.currentSortLabel = [UILabel new];
		self.currentSortLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.currentSortLabel.text = NSLocalizedString(@"localImageSort_name", @"Name");
		self.currentSortLabel.font = [UIFont piwigoFontNormal];
		self.currentSortLabel.textColor = [UIColor piwigoBrown];
        self.currentSortLabel.textAlignment = NSTextAlignmentRight;
		self.currentSortLabel.adjustsFontSizeToFitWidth = YES;
		self.currentSortLabel.minimumScaleFactor = 0.5;
		[self addSubview:self.currentSortLabel];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.currentSortLabel]];

		[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[sort(80)]-[label]-5-[disclosure]-5-|"
																	 options:kNilOptions
																	 metrics:nil
																	   views:@{@"disclosure" : disclosure,
																			   @"label" : self.currentSortLabel,
																			   @"sort" : sortLabel}]];
		
	}
	return self;
}

@end
