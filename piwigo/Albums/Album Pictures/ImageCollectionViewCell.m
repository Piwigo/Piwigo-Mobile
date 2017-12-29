//
//  ImageCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <AFNetworking/AFImageDownloader.h>

#import "ImageCollectionViewCell.h"
#import "PiwigoImageData.h"
#import "Model.h"
#import "NetworkHandler.h"
#import "SAMKeychain.h"

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
		self.backgroundColor = [UIColor whiteColor];
		self.isSelected = NO;
		
        // Images and photos thumbnails
		self.cellImage = [UIImageView new];
		self.cellImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellImage.contentMode = UIViewContentModeScaleAspectFill;
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
        self.playImage.tintColor = [UIColor piwigoOrange];
        self.playImage.hidden = YES;
        self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.playImage.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:self.playImage];
        [self.contentView addConstraints:[NSLayoutConstraint constraintView:self.playImage toSize:CGSizeMake(25, 25)]];
        [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromLeft:self.playImage amount:5]];
        [self.contentView addConstraint:[NSLayoutConstraint constraintViewFromTop:self.playImage amount:5]];

        // Banners at bottom of thumbnails
		self.bottomLayer = [UIView new];
		self.bottomLayer.translatesAutoresizingMaskIntoConstraints = NO;
		self.bottomLayer.backgroundColor = [UIColor piwigoGray];
		self.bottomLayer.alpha = 0.5;
		[self.contentView addSubview:self.bottomLayer];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillWidth:self.bottomLayer]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.bottomLayer amount:0]];
		
        // Title of images shown in banners
		self.nameLabel = [UILabel new];
		self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.nameLabel.font = [UIFont piwigoFontNormal];
		self.nameLabel.textColor = [UIColor piwigoWhiteCream];
		self.nameLabel.adjustsFontSizeToFitWidth = YES;
		self.nameLabel.minimumScaleFactor = 0.5;
		[self.contentView addSubview:self.nameLabel];
		[self.contentView addConstraint:[NSLayoutConstraint constraintCenterVerticalView:self.nameLabel]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.nameLabel amount:5]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeLeft
																	 relatedBy:NSLayoutRelationGreaterThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeLeft
																	multiplier:1.0
																	  constant:5]];
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.nameLabel
																	 attribute:NSLayoutAttributeRight
																	 relatedBy:NSLayoutRelationLessThanOrEqual
																		toItem:self.contentView
																	 attribute:NSLayoutAttributeRight
																	multiplier:1.0
																	  constant:5]];
		
		[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.bottomLayer
																	 attribute:NSLayoutAttributeTop
																	 relatedBy:NSLayoutRelationEqual
																		toItem:self.nameLabel
																	 attribute:NSLayoutAttributeTop
																	multiplier:1.0
																	  constant:-5]];
		
        // Selected image thumbnails
        self.selectedImage = [UIImageView new];
		self.selectedImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.selectedImage.contentMode = UIViewContentModeScaleAspectFit;
		UIImage *checkMark = [UIImage imageNamed:@"checkMark"];
		self.selectedImage.image = [checkMark imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.selectedImage.tintColor = [UIColor piwigoOrange];
		self.selectedImage.hidden = YES;
		[self.contentView addSubview:self.selectedImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintView:self.selectedImage toSize:CGSizeMake(25, 25)]];
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
		[self.contentView addConstraints:[NSLayoutConstraint constraintCenterView:self.noDataLabel]];
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

-(void)setupWithImageData:(PiwigoImageData*)imageData
{
	self.imageData = imageData;

    // Do we have any info on that image ?
	if(!self.imageData)
	{
		self.noDataLabel.hidden = NO;
		return;
	}
	
    // Ensure that any SSL certificate won't be rejected
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    [policy setAllowInvalidCertificates:YES];
    [policy setValidatesDomainName:NO];
    
    AFImageDownloader *dow = [AFImageDownloader defaultInstance];
    [dow.sessionManager setSecurityPolicy:policy];
    
    // Manage servers performing HTTP Basic Access Authentication
    [dow.sessionManager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *credential) {
        
        // HTTP basic authentification credentials
        NSString *user = [Model sharedInstance].HttpUsername;
        NSString *password = [SAMKeychain passwordForService:[NSString stringWithFormat:@"%@%@", [Model sharedInstance].serverProtocol, [Model sharedInstance].serverName] account:user];
        
        // Supply requested credentials if not provided yet
        if (challenge.previousFailureCount == 0) {
            // Trying HTTP credentials…
            *credential = [NSURLCredential credentialWithUser:user
                                                     password:password
                                                  persistence:NSURLCredentialPersistenceForSession];
            return NSURLSessionAuthChallengeUseCredential;
        } else {
            // HTTP credentials refused!
            return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }];

    // Download the image of the requested resolution (or get it from the cache)
    switch ([Model sharedInstance].defaultThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if ([Model sharedInstance].hasSquareSizeImages && (self.imageData.SquarePath) && (self.imageData.SquarePath > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.SquarePath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXXSmall:
            if ([Model sharedInstance].hasXXSmallSizeImages && (self.imageData.XXSmallPath.length > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.XXSmallPath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXSmall:
            if ([Model sharedInstance].hasXSmallSizeImages && (self.imageData.XSmallPath.length > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.XSmallPath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeSmall:
            if ([Model sharedInstance].hasSmallSizeImages && (self.imageData.SmallPath.length > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.SmallPath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeMedium:
            if ([Model sharedInstance].hasMediumSizeImages && (self.imageData.MediumPath.length > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.MediumPath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeLarge:
            if ([Model sharedInstance].hasLargeSizeImages && (self.imageData.LargePath.length > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.LargePath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXLarge:
            if ([Model sharedInstance].hasXLargeSizeImages && (self.imageData.XLargePath.length > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.XLargePath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeXXLarge:
            if ([Model sharedInstance].hasXXLargeSizeImages && (self.imageData.XXLargePath.length > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.XXLargePath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
        case kPiwigoImageSizeThumb:
        case kPiwigoImageSizeFullRes:
        default:
            if ([Model sharedInstance].hasThumbSizeImages && self.imageData.ThumbPath && (self.imageData.ThumbPath > 0)) {
                NSString *URLRequest = [NetworkHandler getURLWithPath:self.imageData.ThumbPath asPiwigoRequest:NO withURLParams:nil];
                [self.cellImage setImageWithURL:[NSURL URLWithString:URLRequest] placeholderImage:[UIImage imageNamed:@"placeholderImage"]];
            } else {
                self.noDataLabel.hidden = NO;
                return;
            }
            break;
    }

    if ([Model sharedInstance].displayImageTitles) {
        self.bottomLayer.hidden = NO;
        self.nameLabel.hidden = NO;
        self.nameLabel.text = imageData.name;
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

@end
