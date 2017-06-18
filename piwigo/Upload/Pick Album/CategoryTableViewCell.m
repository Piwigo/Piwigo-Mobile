//
//  CategoryTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategoryTableViewCell.h"
#import "PiwigoAlbumData.h"
#import "Model.h"

@interface CategoryTableViewCell()

@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) PiwigoAlbumData *categoryData;
@property (nonatomic, strong) UIView *rightHitView;
@property (nonatomic, strong) UIImageView *leftDisclosure;
@property (nonatomic, strong) UIImageView *rightDisclosure;
@property (nonatomic, strong) UILabel *selectLabel;
@property (nonatomic, strong) NSLayoutConstraint *disclosureRightConstraint;

@end

@implementation CategoryTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoWhiteCream];
		
		self.categoryLabel = [UILabel new];
		self.categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.categoryLabel.font = [UIFont piwigoFontNormal];
		self.categoryLabel.adjustsFontSizeToFitWidth = YES;
		self.categoryLabel.minimumScaleFactor = 0.5;
		self.categoryLabel.lineBreakMode = NSLineBreakByTruncatingHead;
		[self.contentView addSubview:self.categoryLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.categoryLabel]];
		
		self.leftDisclosure = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"cellDisclosure"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
		self.leftDisclosure.translatesAutoresizingMaskIntoConstraints = NO;
		self.leftDisclosure.tintColor = [UIColor colorWithRed:199/255.0 green:199/255.0 blue:204/255.0 alpha:1];
		[self.contentView addSubview:self.leftDisclosure];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.leftDisclosure]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.leftDisclosure toSize:CGSizeMake(20, 20)]];
		
		self.selectLabel = [UILabel new];
		self.selectLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectLabel.font = [UIFont piwigoFontNormal];
		self.selectLabel.font = [self.selectLabel.font fontWithSize:13];
		self.selectLabel.textColor = [UIColor lightGrayColor];
		self.selectLabel.textAlignment = NSTextAlignmentRight;
		self.selectLabel.text = NSLocalizedString(@"categoyUpload_loadSubCategories", @"load");
		[self.contentView addSubview:self.selectLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.selectLabel]];
		
		self.rightDisclosure = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
		self.rightDisclosure.translatesAutoresizingMaskIntoConstraints = NO;
		self.rightDisclosure.tintColor = [UIColor lightGrayColor];
		[self.contentView addSubview:self.rightDisclosure];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.rightDisclosure]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.rightDisclosure toSize:CGSizeMake(20, 20)]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[label]-[select][downDisclosure]-10-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"label" : self.categoryLabel,
																						   @"downDisclosure" : self.rightDisclosure,
																						   @"select" : self.selectLabel}]];
		
		self.rightHitView = [UIView new];
		self.rightHitView.translatesAutoresizingMaskIntoConstraints = NO;
		self.rightHitView.backgroundColor = [UIColor piwigoWhiteCream];
		[self.contentView addSubview:self.rightHitView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillHeight:self.rightHitView]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.rightHitView amount:0]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.rightHitView
																	 attribute:NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.selectLabel
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:-10]];
		
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.leftDisclosure
																	 attribute:NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.rightHitView
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:0]];
		
		[self.contentView bringSubviewToFront:self.selectLabel];
		[self.contentView bringSubviewToFront:self.rightDisclosure];
		
		[self.rightHitView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedRightHit)]];
	}
	return self;
}

-(void)setupWithCategoryData:(PiwigoAlbumData*)category
{
	self.categoryData = category;

	NSInteger depth = [self.categoryData getDepthOfCategory];
	if(depth <= 0) depth = 1;
	NSString *front = [@"" stringByPaddingToLength:depth-1 withString:@"-" startingAtIndex:0];
	
	self.categoryLabel.text = [NSString stringWithFormat:@"%@ %@", front, self.categoryData.name];
    self.categoryLabel.backgroundColor = [UIColor piwigoWhiteCream];

	if(category.numberOfSubCategories <= 0 || [Model sharedInstance].loadAllCategoryInfo)
	{
		[self hideRightViews];
	}
	
}

-(void)hideRightViews
{
	self.selectLabel.hidden = YES;
	self.leftDisclosure.hidden = YES;
	self.rightHitView.hidden = YES;
	self.rightDisclosure.image = [[UIImage imageNamed:@"cellDisclosure"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

-(void)setHasLoadedSubCategories:(BOOL)hasLoadedSubCategories
{
	if(hasLoadedSubCategories)
	{
		[self hideRightViews];
	}
}

-(void)tappedRightHit
{
	if([self.categoryDelegate respondsToSelector:@selector(tappedDisclosure:)])
	{
		[self.categoryDelegate tappedDisclosure:self.categoryData];
	}
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
	self.selectLabel.hidden = NO;
	self.leftDisclosure.hidden = NO;
	self.rightHitView.hidden = NO;
	self.categoryLabel.text = @"";
	self.rightDisclosure.image = [[UIImage imageNamed:@"down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark LocalAlbums Methods

-(void)setCellLeftLabel:(NSString*)text
{
	self.categoryLabel.text = text;
    self.categoryLabel.textColor = [UIColor piwigoGray];
	[self hideRightViews];
}

@end
