//
//  UploadHeaderCollectionReusableView.m
//  piwigo
//
//  Created by Spencer Baker on 2/19/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SortHeaderCollectionReusableView.h"
#import "Model.h"

@interface SortHeaderCollectionReusableView()

@end

@implementation SortHeaderCollectionReusableView

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.sortLabel = [UILabel new];
		self.sortLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.sortLabel.text = NSLocalizedString(@"sortBy", @"Sort by");
		self.sortLabel.font = [UIFont piwigoFontNormal];
        self.sortLabel.textColor = [UIColor piwigoLeftLabelColor];
		self.sortLabel.minimumScaleFactor = 0.5;
		self.sortLabel.adjustsFontSizeToFitWidth = YES;
		[self addSubview:self.sortLabel];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.sortLabel]];
		
		self.currentSortLabel = [UILabel new];
		self.currentSortLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.currentSortLabel.text = NSLocalizedString(@"localImageSort_name", @"Name");
		self.currentSortLabel.font = [UIFont piwigoFontNormal];
		self.currentSortLabel.textColor = [UIColor piwigoRightLabelColor];
		self.currentSortLabel.adjustsFontSizeToFitWidth = YES;
		self.currentSortLabel.minimumScaleFactor = 0.5;
		[self addSubview:self.currentSortLabel];
		[self addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.currentSortLabel]];

        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[sort]-[label]-10-|"
                                                                     options:kNilOptions
                                                                     metrics:nil
                                                                       views:@{@"label" : self.currentSortLabel,
                                                                               @"sort" : self.sortLabel}]];
	}
	return self;
}

@end
