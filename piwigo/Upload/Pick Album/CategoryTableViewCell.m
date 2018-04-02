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
//@property (nonatomic, strong) UIImageView *loadDisclosure;
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
        self.cellDisclosure.font = [UIFont piwigoFontDisclosure];
        self.cellDisclosure.textColor = [UIColor piwigoOrange];
        self.cellDisclosure.adjustsFontSizeToFitWidth = NO;
        self.cellDisclosure.minimumScaleFactor = 0.6;
        [self.contentView addSubview:self.cellDisclosure];
        [self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.cellDisclosure]];

        self.loadLabel = [UILabel new];
        self.loadLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.loadLabel.font = [UIFont piwigoFontLight];
        self.loadLabel.textColor = [UIColor piwigoOrange];
        [self.contentView addSubview:self.loadLabel];
        [self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.loadLabel]];
        
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-10-[label]-[load]-[disclosure]-10-|"
                                                                                 options:kNilOptions
                                                                                 metrics:nil
                                                                                   views:@{@"label" : self.categoryLabel,
                                                                                           @"load" : self.loadLabel,
                                                                                           @"disclosure" : self.cellDisclosure
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
				
        [self.contentView bringSubviewToFront:self.loadLabel];

        [self.loadTapView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedLoadView)]];
	}
	return self;
}

-(void)setupWithCategoryData:(PiwigoAlbumData*)category
{
	self.categoryData = category;
    self.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.tintColor = [UIColor piwigoOrange];
    self.textLabel.font = [UIFont piwigoFontNormal];

    // Is this a sub-category?
    NSInteger depth = [self.categoryData getDepthOfCategory];
    if(depth <= 1) {
        // Categories in root album
        self.categoryLabel.text = self.categoryData.name;
        self.categoryLabel.textColor = [UIColor piwigoLeftLabelColor];
    } else {
        // Sub-categories are presented in another color
        self.categoryLabel.textColor = [UIColor piwigoRightLabelColor];

        // Append "—" characters to sub-category names
        NSString *subAlbumPrefix = [@"" stringByPaddingToLength:depth-1 withString:@"—" startingAtIndex:0];
        if ([Model sharedInstance].isAppLanguageRTL) {
            self.categoryLabel.text = [NSString stringWithFormat:@"%@ %@", self.categoryData.name, subAlbumPrefix];
        } else {
            self.categoryLabel.text = [NSString stringWithFormat:@"%@ %@", subAlbumPrefix, self.categoryData.name];
        }
    }
    
    // Show upload button (# sub-albums) if sub-categories are not loaded yet
	if(category.numberOfSubCategories <= 0)
	{
        self.loadLabel.text = @"";
    } else {
        self.loadLabel.text = [NSString stringWithFormat:@"(%ld %@)",
                               (long)self.categoryData.numberOfSubCategories,
                               self.categoryData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
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
}

#pragma mark LocalAlbums Methods

-(void)setCellLeftLabel:(NSString*)text
{
	self.categoryLabel.text = text;
    self.categoryLabel.textColor = [UIColor piwigoLeftLabelColor];
    self.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.tintColor = [UIColor piwigoOrange];
}

@end
