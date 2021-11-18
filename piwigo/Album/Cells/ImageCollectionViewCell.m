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

CGFloat const margin = 1.0;
CGFloat const offset = 1.0;
CGFloat const bannerHeight = 16.0;
CGFloat const favScale = 0.12;
CGFloat const selectScale = 0.2;
CGFloat const playScale = 0.19;
CGFloat const playRatio = 0.7733;

@interface ImageCollectionViewCell()

// On iPad, thumbnails are presented with native aspect ratio
@property (nonatomic, assign) CGFloat deltaX, deltaY;

// Image title
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIView *bottomLayer;
@property (nonatomic, strong) UILabel *noDataLabel;

// Icon showing that it is a favorite
@property (nonatomic, strong) UIImageView *favImg, *favBckg;
@property (nonatomic, strong) NSLayoutConstraint *favLeft, *favBottom;

// Icon showing that it is a movie
@property (nonatomic, strong) UIImageView *playImg, *playBckg;
@property (nonatomic, strong) NSLayoutConstraint *playLeft, *playTop;

// Selected images are darkened
@property (nonatomic, strong) UIImageView *selectedImg;
@property (nonatomic, strong) NSLayoutConstraint *selImgRight, *selImgTop;
@property (nonatomic, strong) UIView *darkenView;
@property (nonatomic, strong) NSLayoutConstraint *darkImgWidth, *darkImgHeight;

@end

@implementation ImageCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
		self.isSelected = NO;
		
        // Thumbnails
		self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
        } else {
            self.cellImage.contentMode = UIViewContentModeScaleAspectFit;
        }
		self.cellImage.image = [UIImage imageNamed:@"placeholderImage"];
		[self.contentView addSubview:self.cellImage];
        [self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.cellImage]];
		
        // Movie type
        self.playBckg = [UIImageView new];
        [self.playBckg setMovieImageInBackground:YES];
        CGFloat scale = fmax(1.0, self.traitCollection.displayScale);
        CGFloat width = frame.size.width * playScale + (scale - 1);
        [self.cellImage addSubview:self.playBckg];
        NSLayoutConstraint *iconWidth = [NSLayoutConstraint constraintView:self.playBckg
                                                                   toWidth:width + 2*offset];
        NSLayoutConstraint *iconHeight = [NSLayoutConstraint constraintView:self.playBckg
                                                                   toHeight:width*playRatio + 2*offset];
        self.playLeft = [NSLayoutConstraint constraintViewFromLeft:self.playBckg amount:margin];
        self.playTop = [NSLayoutConstraint constraintViewFromTop:self.playBckg amount:margin];
        [self.cellImage addConstraints:@[iconWidth, iconHeight, self.playLeft, self.playTop]];
        
        self.playImg = [UIImageView new];
        [self.playImg setMovieImageInBackground:NO];
        [self.playBckg addSubview:self.playImg];
        [self.playBckg addConstraints:[NSLayoutConstraint constraintCenter:self.playImg]];
        [self.cellImage addConstraint:[NSLayoutConstraint constraintView:self.playImg toWidth:width]];
        [self.cellImage addConstraint:[NSLayoutConstraint constraintView:self.playImg toHeight:width*playRatio]];
        
        // Favorite image
        self.favBckg = [UIImageView new];
        [self.favBckg setFavoriteImageInBackground:YES];
        width = frame.size.width * favScale + (scale - 1);
        [self.cellImage addSubview:self.favBckg];
        iconWidth = [NSLayoutConstraint constraintView:self.favBckg
                                               toWidth:width + 2*offset];
        iconHeight = [NSLayoutConstraint constraintView:self.favBckg
                                               toHeight:width*playRatio + 2*offset];
        self.favLeft = [NSLayoutConstraint constraintViewFromLeft:self.favBckg amount:margin];
        self.favBottom = [NSLayoutConstraint constraintViewFromBottom:self.favBckg amount:-margin];
        [self.cellImage addConstraints:@[iconWidth, iconHeight, self.favLeft, self.favBottom]];

        self.favImg = [UIImageView new];
        [self.favImg setFavoriteImageInBackground:NO];
        [self.favBckg addSubview:self.favImg];
        [self.favBckg addConstraints:[NSLayoutConstraint constraintCenter:self.favImg]];
        [self.favBckg addConstraint:[NSLayoutConstraint constraintView:self.favImg toWidth:width]];
        [self.favBckg addConstraint:[NSLayoutConstraint constraintView:self.favImg toHeight:width + 2*offset]];

        // Selected images are darker
        self.darkenView = [UIView new];
        self.darkenView.translatesAutoresizingMaskIntoConstraints = NO;
        self.darkenView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
        self.darkenView.hidden = YES;
        [self.cellImage addSubview:self.darkenView];
        self.darkImgWidth = [NSLayoutConstraint constraintView:self.darkenView
                                                       toWidth:frame.size.width];
        self.darkImgHeight = [NSLayoutConstraint constraintView:self.darkenView
                                                        toHeight:frame.size.height];
        [self.cellImage addConstraints:@[self.darkImgWidth, self.darkImgHeight]];
        [self.cellImage addConstraints:[NSLayoutConstraint constraintCenter:self.darkenView]];

        // Banners at bottom of thumbnails
		self.bottomLayer = [UIView new];
		self.bottomLayer.translatesAutoresizingMaskIntoConstraints = NO;
		self.bottomLayer.alpha = 0.7;
		[self.cellImage addSubview:self.bottomLayer];
		[self.cellImage addConstraints:[NSLayoutConstraint constraintFillWidth:self.bottomLayer]];
		[self.cellImage addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.bottomLayer amount:0]];
        [self.cellImage addConstraint:[NSLayoutConstraint constraintView:self.bottomLayer toHeight:bannerHeight]];
		
        // Title of images shown in banners
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0, self.contentView.bounds.size.width, frame.size.height)];
		self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.nameLabel.font = [UIFont piwigoFontTiny];
		self.nameLabel.adjustsFontSizeToFitWidth = YES;
		self.nameLabel.minimumScaleFactor = 0.7;
        self.nameLabel.numberOfLines = 1;
		[self.bottomLayer addSubview:self.nameLabel];
		[self.bottomLayer addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.nameLabel]];
		[self.bottomLayer addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.nameLabel amount:1]];
		[self.bottomLayer addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationGreaterThanOrEqual
																		toItem:self.bottomLayer
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:3]];
		[self.bottomLayer addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:self.bottomLayer
																	 attribute:NSLayoutAttributeRight
																	multiplier:1.0
																	  constant:3]];
		
		[self.cellImage addConstraint:[NSLayoutConstraint constraintWithItem:self.bottomLayer
																	 attribute:NSLayoutAttributeCenterY
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.nameLabel
																	 attribute:NSLayoutAttributeCenterY
																	multiplier:1.0
																	  constant:0]];
		
        // Selected image thumbnails
        self.selectedImg = [UIImageView new];
		self.selectedImg.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectedImg.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *checkMark = [UIImage imageNamed:@"checkMark"];
		self.selectedImg.image = [checkMark imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.selectedImg.tintColor = [UIColor piwigoColorOrange];
		self.selectedImg.hidden = YES;
		[self.cellImage addSubview:self.selectedImg];
        width = frame.size.width * selectScale + (scale - 1);
		[self.cellImage addConstraint:[NSLayoutConstraint constraintView:self.selectedImg toHeight:width]];
        self.selImgRight = [NSLayoutConstraint constraintViewFromRight:self.selectedImg amount: 0.0];
        self.selImgTop = [NSLayoutConstraint constraintViewFromTop:self.selectedImg amount: 2*margin];
        [self.cellImage addConstraints:@[self.selImgRight, self.selImgTop]];
		
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

-(void)setupWithImageData:(PiwigoImageData*)imageData inCategoryId:(NSInteger)categoryId
{
	self.imageData = imageData;
    self.isAccessibilityElement = YES;

    // Do we have any info on that image ?
	if (!self.imageData) {
		self.noDataLabel.hidden = NO;
		return;
	}
	
    // Play button
    self.playImg.hidden = !imageData.isVideo;
    self.playBckg.hidden = !imageData.isVideo;

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
    
    // Download the image of the requested resolution (or get it from the cache)
    switch (AlbumVars.defaultThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if (AlbumVars.hasSquareSizeImages && (self.imageData.SquarePath) && (self.imageData.SquarePath > 0)) {
                [self setImageFromPath:self.imageData.SquarePath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if (AlbumVars.hasXXSmallSizeImages && (self.imageData.XXSmallPath.length > 0)) {
                [self setImageFromPath:self.imageData.XXSmallPath];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXSmall:
            if (AlbumVars.hasXSmallSizeImages && (self.imageData.XSmallPath.length > 0)) {
                [self setImageFromPath:self.imageData.XSmallPath];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeSmall:
            if (AlbumVars.hasSmallSizeImages && (self.imageData.SmallPath.length > 0)) {
                [self setImageFromPath:self.imageData.SmallPath];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeMedium:
            if (AlbumVars.hasMediumSizeImages && (self.imageData.MediumPath.length > 0)) {
                [self setImageFromPath:self.imageData.MediumPath];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeLarge:
            if (AlbumVars.hasLargeSizeImages && (self.imageData.LargePath.length > 0)) {
                [self setImageFromPath:self.imageData.LargePath];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXLarge:
            if (AlbumVars.hasXLargeSizeImages && (self.imageData.XLargePath.length > 0)) {
                [self setImageFromPath:self.imageData.XLargePath];
            } else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXXLarge:
            if (AlbumVars.hasXXLargeSizeImages && (self.imageData.XXLargePath.length > 0)) {
                [self setImageFromPath:self.imageData.XXLargePath];
            }
            else if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeThumb:
        case kPiwigoImageSizeFullRes:
        default:
            if (AlbumVars.hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                [self setImageFromPath:self.imageData.ThumbPath];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
    }
}

-(void)setImageFromPath:(NSString *)imagePath
{
    __weak typeof(self) weakSelf = self;
    [self.cellImage layoutIfNeeded];
    CGSize size = self.cellImage.bounds.size;
    CGFloat scale = fmax(1.0, self.traitCollection.displayScale);
    NSURL *URL = [NSURL URLWithString:imagePath];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    [self.cellImage setImageWithURLRequest:request
                          placeholderImage:[UIImage imageNamed:@"placeholderImage"]
                                   success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull image) {
        // Downsample image (or scale it up)
        UIImage *displayedImage = [ImageUtilities downsampleWithImage:image to:size scale:scale];
        weakSelf.cellImage.image = displayedImage;
        [weakSelf.cellImage layoutIfNeeded];
        
        // Favorite image position depends on device
        weakSelf.deltaX = margin; weakSelf.deltaY = margin;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            // Case of an iPad: respect aspect ratio
            // Image width…
            CGFloat imageWidth = displayedImage.size.width / scale;
            weakSelf.darkImgWidth.constant = imageWidth;

            // Horizontal correction?
            CGFloat cellWidth = size.width;
            if (imageWidth < cellWidth) {
                // The image does not fill the cell horizontally
                weakSelf.deltaX += (cellWidth - imageWidth) / 2.0;
            }

            // Image height…
            CGFloat imageHeight = displayedImage.size.height / scale;
            weakSelf.darkImgHeight.constant = imageHeight;

            // Vertical correction?
            CGFloat cellHeight = size.height;
            if (imageHeight < cellHeight) {
                // The image does not fill the cell vertically
                weakSelf.deltaY += (cellHeight - imageHeight) / 2.0;
            }
        }
        
        // Update horizontal constraints
        weakSelf.selImgRight.constant = -weakSelf.deltaX;
        weakSelf.favLeft.constant = weakSelf.deltaX;
        weakSelf.playLeft.constant = weakSelf.deltaX;

        // Update vertical constraints
        weakSelf.selImgTop.constant = weakSelf.deltaY + 2*margin;
        weakSelf.playTop.constant = weakSelf.deltaY + offset;
        if (weakSelf.bottomLayer.isHidden) {
            // The title is not displayed
            weakSelf.favBottom.constant = - (weakSelf.deltaY +2);
        } else {
            // The title is displayed
            CGFloat deltaY = fmax(bannerHeight + margin, weakSelf.deltaY + 2);
            weakSelf.favBottom.constant = - deltaY;
        }
    } failure:nil];
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    self.cellImage.image = nil;
    self.deltaX = margin; self.deltaY = margin;
	self.isSelected = NO;
    self.isFavorite = NO;
	self.playImg.hidden = YES;
	self.noDataLabel.hidden = YES;
}

-(void)setIsSelected:(BOOL)isSelected
{
	_isSelected = isSelected;

	self.selectedImg.hidden = !isSelected;
	self.darkenView.hidden = !isSelected;
}

-(void)setIsFavorite:(BOOL)isFavorite
{
    _isFavorite = isFavorite;

    // Update the vertical constraint
    if (self.bottomLayer.isHidden) {
        // Place icon at the bottom
        self.favBottom.constant = - (self.deltaY + 2);
    }
    else {
        // Place icon at the bottom but above the title
        CGFloat height = fmax(bannerHeight + margin, self.deltaY + 2);
        self.favBottom.constant = - height;
    }
    
    // Display/hide the favorite icon
    self.favBckg.hidden = !isFavorite;
    self.favImg.hidden = !isFavorite;
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
