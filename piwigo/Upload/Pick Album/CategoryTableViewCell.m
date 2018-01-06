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
@property (nonatomic, strong) UIView *loadTapView;
@property (nonatomic, strong) UIImageView *loadDisclosure;
@property (nonatomic, strong) UILabel *cellDisclosure;
@property (nonatomic, strong) UILabel *loadLabel;
@property (nonatomic, strong) NSLayoutConstraint *disclosureRightConstraint;

@end

@implementation CategoryTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self)
	{
//		self.backgroundColor = [UIColor piwigoWhiteCream];
		
		self.categoryLabel = [UILabel new];
		self.categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.categoryLabel.font = [UIFont piwigoFontNormal];
		self.categoryLabel.adjustsFontSizeToFitWidth = YES;
		self.categoryLabel.minimumScaleFactor = 0.5;
		self.categoryLabel.lineBreakMode = NSLineBreakByTruncatingHead;
		[self.contentView addSubview:self.categoryLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.categoryLabel]];
		
        self.cellDisclosure = [UILabel new];
        if ([Model sharedInstance].isAppLanguageRTL) {
            self.cellDisclosure.text = @"<";
            self.cellDisclosure.textAlignment = NSLayoutAttributeLeftMargin;
        } else {
            self.cellDisclosure.text = @">";
            self.cellDisclosure.textAlignment = NSLayoutAttributeRight;
        }
        self.cellDisclosure.translatesAutoresizingMaskIntoConstraints = NO;
        self.cellDisclosure.font = [UIFont piwigoFontNormal];
        self.cellDisclosure.font = [self.cellDisclosure.font fontWithSize:21.0];
        self.cellDisclosure.textColor = [UIColor piwigoOrange];
        self.cellDisclosure.adjustsFontSizeToFitWidth = NO;
        self.cellDisclosure.minimumScaleFactor = 0.6;
        [self.contentView addSubview:self.cellDisclosure];
        [self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.cellDisclosure]];
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[label]-[disclosure]-10-|"
                                                                                 options:kNilOptions
                                                                                 metrics:nil
                                                                                   views:@{@"label" : self.categoryLabel,
                                                                                           @"disclosure" : self.cellDisclosure
                                                                                           }]];

		self.loadLabel = [UILabel new];
		self.loadLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.loadLabel.font = [UIFont piwigoFontNormal];
		self.loadLabel.font = [self.loadLabel.font fontWithSize:13];
		self.loadLabel.textColor = [UIColor lightGrayColor];
		self.loadLabel.text = NSLocalizedString(@"categoyUpload_loadSubCategories", @"load");
		[self.contentView addSubview:self.loadLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.loadLabel]];
		
		self.loadDisclosure = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
		self.loadDisclosure.translatesAutoresizingMaskIntoConstraints = NO;
		self.loadDisclosure.tintColor = [UIColor lightGrayColor];
		[self.contentView addSubview:self.loadDisclosure];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.loadDisclosure]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.loadDisclosure toSize:CGSizeMake(28, 28)]];
		[self.contentView addConstraints:[NSLayoutConstraint
                                          constraintsWithVisualFormat:@"|-10-[label]-[load]-[downDisclosure]-10-|"
                                                               options:kNilOptions
                                                              metrics:nil
                                                                views:@{@"label" : self.categoryLabel,
                                                                        @"load" : self.loadLabel,
                                                                        @"downDisclosure" : self.loadDisclosure
                                                                        }]];
		
		self.loadTapView = [UIView new];
		self.loadTapView.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:self.loadTapView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillHeight:self.loadTapView]];
        if ([Model sharedInstance].isAppLanguageRTL) {
            [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromLeft:self.loadTapView amount:0]];
            [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.loadTapView
                                                                         attribute:NSLayoutAttributeRight
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.loadLabel
                                                                         attribute:NSLayoutAttributeRight
                                                                        multiplier:1.0
                                                                          constant:10]];
        } else {
            [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.loadTapView amount:0]];
            [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.loadTapView
                                                                         attribute:NSLayoutAttributeLeft
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.loadLabel
                                                                         attribute:NSLayoutAttributeLeft
                                                                        multiplier:1.0
                                                                          constant:-10]];
        }
				
		[self.contentView bringSubviewToFront:self.loadDisclosure];
        [self.contentView bringSubviewToFront:self.loadLabel];

		[self.loadTapView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedLoadView)]];
	}
	return self;
}

-(void)setupWithCategoryData:(PiwigoAlbumData*)category
{
	self.categoryData = category;

    // Is this a sub-category?
    NSInteger depth = [self.categoryData getDepthOfCategory];
    if(depth <= 1) {
        // Categories
        self.categoryLabel.text = self.categoryData.name;
        self.categoryLabel.textColor = [UIColor piwigoLeftLabelColor];
    } else {
        // Sub-categories are presented in another color
        self.categoryLabel.textColor = [UIColor piwigoRightLabelColor];

        // Append "—" characters to sub-category names
        NSString *subAlbumMark = [@"" stringByPaddingToLength:depth-1 withString:@"—" startingAtIndex:0];
        if ([Model sharedInstance].isAppLanguageRTL) {
            self.categoryLabel.text = [NSString stringWithFormat:@"%@ %@", self.categoryData.name, subAlbumMark];
        } else {
            self.categoryLabel.text = [NSString stringWithFormat:@"%@ %@", subAlbumMark, self.categoryData.name];
        }
    }
    
    // Show upload button if sub-categories are not loaded yet
	if(category.numberOfSubCategories <= 0 || [Model sharedInstance].loadAllCategoryInfo)
	{
		[self hideUploadViews];
        self.cellDisclosure.hidden = NO;
    } else {
        [self showUploadViews];
        self.cellDisclosure.hidden = YES;
    }
}

-(void)showUploadViews
    {
        self.loadLabel.hidden = NO;
        self.loadTapView.hidden = NO;
        self.loadDisclosure.hidden = NO;
    }

-(void)hideUploadViews
{
    self.loadLabel.hidden = YES;
	self.loadTapView.hidden = YES;
    self.loadDisclosure.hidden = YES;
}

-(void)setHasLoadedSubCategories:(BOOL)hasLoadedSubCategories
{
	if(hasLoadedSubCategories)
	{
		[self hideUploadViews];
        self.cellDisclosure.hidden = NO;
	}
}

-(void)tappedLoadView
{
	if([self.categoryDelegate respondsToSelector:@selector(tappedDisclosure:)])
	{
		[self.categoryDelegate tappedDisclosure:self.categoryData];
	}
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
    self.categoryLabel.text = @"";
    self.loadDisclosure.image = [[UIImage imageNamed:@"down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark LocalAlbums Methods

-(void)setCellLeftLabel:(NSString*)text
{
	self.categoryLabel.text = text;
    self.categoryLabel.textColor = [UIColor piwigoLeftLabelColor];
    self.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.tintColor = [UIColor piwigoOrange];

    [self hideUploadViews];
    self.cellDisclosure.hidden = NO;
}

@end
