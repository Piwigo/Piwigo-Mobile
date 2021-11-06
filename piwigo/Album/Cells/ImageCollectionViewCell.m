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

CGFloat const favMargin = 1.0;
CGFloat const favOffset = 1.0;
CGFloat const favScale = 0.12;
CGFloat const selectScale = 0.2;
CGFloat const playScale = 0.15;

@interface ImageCollectionViewCell()

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIView *bottomLayer;
@property (nonatomic, assign) CGFloat deltaX, deltaY;
@property (nonatomic, strong) UIImageView *selectedImage;
@property (nonatomic, strong) NSLayoutConstraint *selImgRight, *selImgTop;
@property (nonatomic, strong) UIImageView *favoriteImage;
@property (nonatomic, strong) NSLayoutConstraint *favImgLeft, *favImgBottom;
@property (nonatomic, strong) UIImageView *favoriteBckgImage;
@property (nonatomic, strong) NSLayoutConstraint *favBckgImgLeft, *favBckgImgBottom;
@property (nonatomic, strong) UIView *darkenView;
@property (nonatomic, strong) NSLayoutConstraint *darkImgWidth, *darkImgHeight;
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
        UIImage *play;
        if (@available(iOS 13.0, *)) {
            play = [UIImage systemImageNamed:@"play.square.fill"];
        } else {
            play = [UIImage imageNamed:@"video"];
        }
        self.playImage = [UIImageView new];
        self.playImage.image = [play imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.playImage.tintColor = [UIColor piwigoColorOrange];
        self.playImage.hidden = YES;
        self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.playImage.contentMode = UIViewContentModeScaleAspectFit;
        CGFloat scale = fmax(1.0, self.traitCollection.displayScale);
        CGFloat dim = frame.size.width * playScale + (scale - 1);
        CGSize imgSize = CGSizeMake(dim, dim);
        [self.cellImage addSubview:self.playImage];
        [self.cellImage addConstraints:[NSLayoutConstraint constraintView:self.playImage to:imgSize]];
        [self.cellImage addConstraint:[NSLayoutConstraint constraintViewFromLeft:self.playImage amount:5]];
        [self.cellImage addConstraint:[NSLayoutConstraint constraintViewFromTop:self.playImage amount:5]];
        
        // Favorite image
        UIImage *favorite;
        if (@available(iOS 13.0, *)) {
            favorite = [UIImage systemImageNamed:@"heart.fill"];
        } else {
            favorite = [UIImage imageNamed:@"imageFavorite"];
        }
        dim = frame.size.width * favScale + (scale - 1);
        imgSize = CGSizeMake(dim, dim);
        CGSize bckgSize = CGSizeMake(dim + 2*favOffset, dim + 2*favOffset);
        self.favoriteBckgImage = [UIImageView new];
        self.favoriteBckgImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.favoriteBckgImage.contentMode = UIViewContentModeScaleAspectFit;
        self.favoriteBckgImage.image = [favorite imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.favoriteBckgImage.tintColor = [UIColor colorWithWhite:0.0 alpha:0.1];
        self.favoriteBckgImage.hidden = YES;
        [self.cellImage addSubview:self.favoriteBckgImage];
        [self.cellImage addConstraints:[NSLayoutConstraint constraintView:self.favoriteBckgImage
                                                                       to:bckgSize]];
        self.deltaX = favMargin; self.deltaY = favMargin;
        self.favBckgImgLeft = [NSLayoutConstraint constraintViewFromLeft:self.favoriteBckgImage
                                                                    amount:self.deltaX];
        self.favBckgImgBottom = [NSLayoutConstraint constraintViewFromBottom:self.favoriteBckgImage
                                                                        amount:-self.deltaY];
        [self.cellImage addConstraints:@[self.favBckgImgLeft, self.favBckgImgBottom]];

        self.favoriteImage = [UIImageView new];
        self.favoriteImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.favoriteImage.contentMode = UIViewContentModeScaleAspectFit;
        self.favoriteImage.image = [favorite imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.favoriteImage.tintColor = [UIColor whiteColor];
        self.favoriteImage.hidden = YES;
        [self.cellImage addSubview:self.favoriteImage];
        [self.cellImage addConstraints:[NSLayoutConstraint constraintView:self.favoriteImage
                                                                       to:imgSize]];
        self.favImgLeft = [NSLayoutConstraint constraintViewFromLeft:self.favoriteImage
                                                              amount:self.deltaX + favOffset];
        self.favImgBottom = [NSLayoutConstraint constraintViewFromBottom:self.favoriteImage
                                                                  amount:-(self.deltaY + favOffset)];
        [self.cellImage addConstraints:@[self.favImgLeft, self.favImgBottom]];

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
        [self.cellImage addConstraint:[NSLayoutConstraint constraintView:self.bottomLayer toHeight:16.0]];
		
        // Title of images shown in banners
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0, self.contentView.bounds.size.width, CGFLOAT_MAX)];
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
        self.selectedImage = [UIImageView new];
		self.selectedImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectedImage.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *checkMark = [UIImage imageNamed:@"checkMark"];
		self.selectedImage.image = [checkMark imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.selectedImage.tintColor = [UIColor piwigoColorOrange];
		self.selectedImage.hidden = YES;
		[self.cellImage addSubview:self.selectedImage];
        dim = frame.size.width * selectScale + (scale - 1);
        imgSize = CGSizeMake(dim, dim);
		[self.cellImage addConstraints:[NSLayoutConstraint constraintView:self.selectedImage
                                                                       to:imgSize]];
        self.selImgRight = [NSLayoutConstraint constraintViewFromRight:self.selectedImage
                                                                amount: 0.0];
        self.selImgTop = [NSLayoutConstraint constraintViewFromTop:self.selectedImage
                                                            amount: 5.0];
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
    self.playImage.hidden = !imageData.isVideo;

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
        weakSelf.deltaX = favMargin; weakSelf.deltaY = favMargin;
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
        weakSelf.favImgLeft.constant = weakSelf.deltaX + favOffset;
        weakSelf.favBckgImgLeft.constant = weakSelf.deltaX;

        // Update vertical constraints
        weakSelf.selImgTop.constant = weakSelf.deltaY + 5.0;
        if (weakSelf.bottomLayer.isHidden) {
            // The title is not displayed
            weakSelf.favImgBottom.constant = - (weakSelf.deltaY + favOffset);
            weakSelf.favBckgImgBottom.constant = -weakSelf.deltaY;
        } else {
            // The title is displayed
            CGFloat deltaY = fmax(16.0, weakSelf.deltaY);
            weakSelf.favImgBottom.constant = - (deltaY + favOffset);
            weakSelf.favBckgImgBottom.constant = - deltaY;
        }
    } failure:nil];
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    self.cellImage.image = nil;
    self.deltaX = favMargin; self.deltaY = favMargin;
	self.isSelected = NO;
    self.isFavorite = NO;
	self.playImage.hidden = YES;
	self.noDataLabel.hidden = YES;
}

-(void)setIsSelected:(BOOL)isSelected
{
	_isSelected = isSelected;

	self.selectedImage.hidden = !isSelected;
	self.darkenView.hidden = !isSelected;
}

-(void)setIsFavorite:(BOOL)isFavorite
{
    _isFavorite = isFavorite;

    // Update the vertical constraint
    if (self.bottomLayer.isHidden) {
        // Place icon at the bottom
        self.favImgBottom.constant = - (self.deltaY + favOffset);
        self.favBckgImgBottom.constant = - self.deltaY;
    }
    else {
        // Place icon at the bottom but above the title
        CGFloat height = fmax(16.0, self.deltaY);
        self.favImgBottom.constant = - (height + favOffset);
        self.favBckgImgBottom.constant = - height;
    }
    
    // Display/hide the favorite icon
    self.favoriteBckgImage.hidden = !isFavorite;
    self.favoriteImage.hidden = !isFavorite;
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
