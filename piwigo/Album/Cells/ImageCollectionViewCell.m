//
//  ImageCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageCollectionViewCell.h"
#import "PiwigoImageData.h"
#import "PiwigoAlbumData.h"
#import "NetworkHandler.h"

@interface ImageCollectionViewCell()

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIView *bottomLayer;
@property (nonatomic, strong) UIImageView *selectedImage;
@property (nonatomic, strong) UIView *darkenView;
@property (nonatomic, strong) UIImageView *playImage;
@property (nonatomic, strong) UILabel *noDataLabel;

@end

@implementation ImageCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor clearColor];
		self.isSelected = NO;
		
        // Thumbnails
		self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
        } else {
            self.cellImage.contentMode = UIViewContentModeScaleAspectFit;
        }
		self.cellImage.clipsToBounds = YES;
		self.cellImage.image = [UIImage imageNamed:@"placeholderImage"];
		[self.contentView addSubview:self.cellImage];
        [self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.cellImage]];
		
		// Selected images are darker
        self.darkenView = [UIView new];
		self.darkenView.translatesAutoresizingMaskIntoConstraints = NO;
		self.darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
		self.darkenView.hidden = YES;
		[self.contentView addSubview:self.darkenView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.darkenView]];
		
        // Movie type
        self.playImage = [UIImageView new];
        UIImage *play = [UIImage imageNamed:@"video"];
        self.playImage.image = [play imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.playImage.tintColor = [UIColor piwigoColorOrange];
        self.playImage.hidden = YES;
        self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.playImage.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.playImage];
        [self.contentView addConstraints:[NSLayoutConstraint constraintView:self.playImage to:CGSizeMake(25, 25)]];
        [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromLeft:self.playImage amount:5]];
        [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromTop:self.playImage amount:5]];

        // Banners at bottom of thumbnails
		self.bottomLayer = [UIView new];
		self.bottomLayer.translatesAutoresizingMaskIntoConstraints = NO;
		self.bottomLayer.alpha = 0.7;
		[self.contentView addSubview:self.bottomLayer];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillWidth:self.bottomLayer]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.bottomLayer amount:0]];
		
        // Title of images shown in banners
		self.nameLabel = [UILabel new];
		self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.nameLabel.font = [UIFont piwigoFontTiny];
		self.nameLabel.adjustsFontSizeToFitWidth = YES;
		self.nameLabel.minimumScaleFactor = 0.7;
        self.nameLabel.numberOfLines = 1;
		[self.contentView addSubview:self.nameLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.nameLabel]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.nameLabel amount:1]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationGreaterThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:3]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeRight
																	multiplier:1.0
																	  constant:3]];
		
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.bottomLayer
																	 attribute:NSLayoutAttributeCenterY
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.nameLabel
																	 attribute:NSLayoutAttributeCenterY
																	multiplier:1.0
																	  constant:0]];
		
        // Selected image thumbnails
        self.selectedImage = [UIImageView new];
		self.selectedImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectedImage.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *checkMark = [UIImage imageNamed:@"checkMark"];
		self.selectedImage.image = [checkMark imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.selectedImage.tintColor = [UIColor piwigoColorOrange];
		self.selectedImage.hidden = YES;
		[self.contentView addSubview:self.selectedImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.selectedImage to:CGSizeMake(25, 25)]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.selectedImage amount:0]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromTop:self.selectedImage amount:5]];
		
        // Without data to show
		self.noDataLabel = [UILabel new];
		self.noDataLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.noDataLabel.font = [UIFont piwigoFontNormal];
		self.noDataLabel.textColor = [UIColor redColor];
		self.noDataLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
		self.noDataLabel.layer.cornerRadius = 3.0;
		self.noDataLabel.text = NSLocalizedString(@"categoryImageList_noDataError", @"Error No Data");
		self.noDataLabel.hidden = YES;
		[self.contentView addSubview:self.noDataLabel];
		[self.contentView addConstraints:[NSLayoutConstraint constraintCenter:self.noDataLabel]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.noDataLabel
																	 attribute:NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationGreaterThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:0]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.noDataLabel
																	 attribute:NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeRight
																	multiplier:1.0
																	  constant:0]];
	}
	return self;
}

-(void)setupWithImageData:(PiwigoImageData*)imageData forCategoryId:(NSInteger)categoryId
{
	self.imageData = imageData;
    self.isAccessibilityElement = YES;

    // Do we have any info on that image ?
	if(!self.imageData)
	{
		self.noDataLabel.hidden = NO;
		return;
	}
	
    // Download the image of the requested resolution (or get it from the cache)
    switch (AlbumVars.defaultThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if (AlbumVars.hasSquareSizeImages && (self.imageData.SquarePath) && (self.imageData.SquarePath > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.SquarePath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if (AlbumVars.hasXXSmallSizeImages && (self.imageData.XXSmallPath.length > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.XXSmallPath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                    NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                    [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXSmall:
            if (AlbumVars.hasXSmallSizeImages && (self.imageData.XSmallPath.length > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.XSmallPath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                    NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                    [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeSmall:
            if (AlbumVars.hasSmallSizeImages && (self.imageData.SmallPath.length > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.SmallPath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                    NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                    [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeMedium:
            if (AlbumVars.hasMediumSizeImages && (self.imageData.MediumPath.length > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.MediumPath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                    NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                    [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeLarge:
            if (AlbumVars.hasLargeSizeImages && (self.imageData.LargePath.length > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.LargePath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                    NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                    [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXLarge:
            if (AlbumVars.hasXLargeSizeImages && (self.imageData.XLargePath.length > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.XLargePath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXXLarge:
            if (AlbumVars.hasXXLargeSizeImages && (self.imageData.XXLargePath.length > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.XXLargePath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            }
            else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                    NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                    [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeThumb:
        case kPiwigoImageSizeFullRes:
        default:
            if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                NSURL *URL = [NSURL URLWithString:self.imageData.ThumbPath];
                [self.cellImage setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
    }

    // Title
    if ((AlbumVars.displayImageTitles) ||
        (categoryId == kPiwigoVisitsCategoryId)     ||
        (categoryId == kPiwigoBestCategoryId)       ||
        (categoryId == kPiwigoRecentCategoryId)) {
        self.bottomLayer.hidden = NO;
        self.bottomLayer.backgroundColor = [UIColor piwigoColorBackground];
        self.nameLabel.hidden = NO;
        self.nameLabel.textColor = [UIColor piwigoColorLeftLabel];
        if (categoryId == kPiwigoVisitsCategoryId) {
            self.nameLabel.text = [NSString stringWithFormat:@"%ld %@", (long)imageData.visits, NSLocalizedString(@"categoryDiscoverVisits_legend", @"hits")];
        } else if (categoryId == kPiwigoBestCategoryId) {
//            self.nameLabel.text = [NSString stringWithFormat:@"(%.2f) %@", imageData.ratingScore, imageData.name];
            self.nameLabel.text = imageData.imageTitle.length ? imageData.imageTitle : imageData.fileName;
        } else if (categoryId == kPiwigoRecentCategoryId) {
            self.nameLabel.text = [NSDateFormatter localizedStringFromDate:imageData.dateCreated dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
        } else {
            self.nameLabel.text = imageData.imageTitle.length ? imageData.imageTitle : imageData.fileName;
        }
    } else {
        self.bottomLayer.hidden = YES;
        self.nameLabel.hidden = YES;
    }
    
	if(imageData.isVideo)
	{
//		self.darkenView.hidden = NO;
		self.playImage.hidden = NO;
	}
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    self.cellImage.image = nil;
	self.isSelected = NO;
	self.playImage.hidden = YES;
	self.noDataLabel.hidden = YES;
}

-(void)setIsSelected:(BOOL)isSelected
{
	_isSelected = isSelected;

	self.selectedImage.hidden = !isSelected;
	self.darkenView.hidden = !isSelected;
}

-(void)highlightOnCompletion:(void (^)(void))completion
{
    // Select cell of image of interest and apply effect
    self.backgroundColor = [UIColor piwigoColorBackground];
    self.contentMode = UIViewContentModeScaleAspectFit;
    [UIView animateWithDuration:0.4 delay:0.3 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        [self.cellImage setAlpha:0.2];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.4 delay:0.7 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            [self.cellImage setAlpha:1.0];
        } completion:^(BOOL finished) {
            completion();
        }];
    }];
}

@end
