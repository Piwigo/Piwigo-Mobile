//
//  CategoryTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryTableViewCell.h"
#import "PiwigoAlbumData.h"

@interface CategoryTableViewCell()

@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) PiwigoAlbumData *categoryData;
@property (nonatomic, strong) UIView *rightHitView;

@end

@implementation CategoryTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		
		self.categoryLabel = [UILabel new];
		self.categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.categoryLabel.font = [UIFont piwigoFontNormal];
		self.categoryLabel.lineBreakMode = NSLineBreakByTruncatingHead;
		[self.contentView addSubview:self.categoryLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.categoryLabel]];
		
		
		self.rightHitView = [UIView new];
		self.rightHitView.translatesAutoresizingMaskIntoConstraints = NO;
		self.rightHitView.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:self.rightHitView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillHeight:self.rightHitView]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintView:self.rightHitView toWidth:60]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.rightHitView amount:0]];
		
		[self.rightHitView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedRightHit)]];
		
		UIImageView *disclosure = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"cellDisclosure"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
		disclosure.translatesAutoresizingMaskIntoConstraints = NO;
		disclosure.tintColor = [UIColor colorWithRed:199/255.0 green:199/255.0 blue:204/255.0 alpha:1];
		[self.contentView addSubview:disclosure];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:disclosure]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:disclosure toSize:CGSizeMake(20, 20)]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[label]-[disclosure]-10-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"label" : self.categoryLabel,
																						   @"disclosure" : disclosure}]];
		
	}
	return self;
}

-(void)setupWithCategoryData:(PiwigoAlbumData*)category
{
	self.categoryData = category;

	NSInteger depth = [self.categoryData getDepthOfCategory];
	NSString *front = [@"" stringByPaddingToLength:depth withString:@" " startingAtIndex:0];
	
	self.categoryLabel.text = [NSString stringWithFormat:@"%@%@", front, self.categoryData.name];
}

-(void)tappedRightHit
{
	if([self.categoryDelegate respondsToSelector:@selector(tappedDisclosure:)])
	{
		[self.categoryDelegate tappedDisclosure:self.categoryData];
	}
}

@end
