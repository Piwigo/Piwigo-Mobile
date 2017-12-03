//
//  AlbumTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <AFNetworking/AFImageDownloader.h>

#import "AlbumTableViewCell.h"
#import "PiwigoAlbumData.h"
#import "ImageService.h"
#import "LEColorPicker.h"
#import "OutlinedText.h"
#import "Model.h"
#import "AlbumService.h"
#import "CategoriesData.h"
#import "MoveCategoryViewController.h"
#import "NetworkHandler.h"
#import "MBProgressHUD.h"


@interface AlbumTableViewCell() <UITextFieldDelegate>

@property (nonatomic, strong) UIImageView *backgroundImage;
@property (nonatomic, strong) OutlinedText *albumName;
@property (nonatomic, strong) UILabel *numberOfImages;
@property (nonatomic, strong) UILabel *date;
@property (nonatomic, strong) UIView *textUnderlay;
@property (nonatomic, strong) UIImageView *cellDisclosure;
@property (nonatomic, strong) NSURLSessionTask *cellDataRequest;
@property (nonatomic, strong) UIAlertAction *categoryAction;
@property (nonatomic, strong) UIAlertAction *deleteAction;

@end

@implementation AlbumTableViewCell

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoGray];
		
		self.backgroundImage = [UIImageView new];
		self.backgroundImage.translatesAutoresizingMaskIntoConstraints = NO;
		self.backgroundImage.contentMode = UIViewContentModeScaleAspectFill;
		self.backgroundImage.clipsToBounds = YES;
		self.backgroundImage.backgroundColor = [UIColor piwigoGray];
		self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];
		[self.contentView addSubview:self.backgroundImage];
		[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-5-[img]-5-|"
																				 options:kNilOptions
																				 metrics:nil
																				   views:@{@"img" : self.backgroundImage}]];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillHeight:self.backgroundImage]];
		
		if(IS_OS_8_OR_LATER)
		{
			UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
			self.textUnderlay = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
		}
		else
		{
			self.textUnderlay = [UIView new];
			self.textUnderlay.alpha = 0.5;
		}
		self.textUnderlay.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:self.textUnderlay];
		
		self.albumName = [OutlinedText new];
		self.albumName.translatesAutoresizingMaskIntoConstraints = NO;
		self.albumName.font = [UIFont piwigoFontNormal];
		self.albumName.font = [self.albumName.font fontWithSize:21.0];
		self.albumName.textColor = [UIColor piwigoOrange];
		self.albumName.adjustsFontSizeToFitWidth = YES;
		self.albumName.minimumScaleFactor = 0.6;
		[self.contentView addSubview:self.albumName];
		
		self.numberOfImages = [UILabel new];
		self.numberOfImages.translatesAutoresizingMaskIntoConstraints = NO;
		self.numberOfImages.font = [UIFont piwigoFontNormal];
		self.numberOfImages.font = [self.numberOfImages.font fontWithSize:16.0];
		self.numberOfImages.textColor = [UIColor piwigoWhiteCream];
		self.numberOfImages.adjustsFontSizeToFitWidth = YES;
		self.numberOfImages.minimumScaleFactor = 0.8;
		self.numberOfImages.lineBreakMode = NSLineBreakByTruncatingTail;
		[self.numberOfImages setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
		[self.contentView addSubview:self.numberOfImages];
		
		self.date = [UILabel new];
		self.date.translatesAutoresizingMaskIntoConstraints = NO;
		self.date.font = [UIFont piwigoFontNormal];
		self.date.font = [self.date.font fontWithSize:16.0];
		self.date.textColor = [UIColor piwigoWhiteCream];
		self.date.textAlignment = NSTextAlignmentRight;
		[self.date setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
		[self.contentView addSubview:self.date];
		
		UIImage *cellDisclosureImg = [UIImage imageNamed:@"cellDisclosure"];
		self.cellDisclosure = [UIImageView new];
		self.cellDisclosure.translatesAutoresizingMaskIntoConstraints = NO;
		self.cellDisclosure.image = [cellDisclosureImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
		self.cellDisclosure.tintColor = [UIColor piwigoWhiteCream];
		self.cellDisclosure.contentMode = UIViewContentModeScaleAspectFit;
		[self.contentView addSubview:self.cellDisclosure];
		
		[self setupAutoLayout];
		
        // Add renaming, moving and deleting capabilities when user has admin rights
		if([Model sharedInstance].hasAdminRights)
		{
			self.rightSwipeSettings.transition = MGSwipeTransitionBorder;
            self.rightButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"SwipeRename.png"]
                                                 backgroundColor:[UIColor piwigoOrange]
                                                        callback:^BOOL(MGSwipeTableCell *sender) {
                                                            [self renameCategory];
                                                            return YES;
                                                        }],
								  [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"SwipeMove.png"]
												 backgroundColor:[UIColor piwigoGrayLight]
														callback:^BOOL(MGSwipeTableCell *sender) {
															[self moveCategory];
															return YES;
														}],
                                   [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"SwipeTrash.png"]
												 backgroundColor:[UIColor redColor]
														callback:^BOOL(MGSwipeTableCell *sender) {
															[self deleteCategory];
															return YES;
														}]];
		}
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageUpdated) name:kPiwigoNotificationCategoryImageUpdated object:nil];
		
	}
	return self;
}

-(void)setupAutoLayout
{
	NSDictionary *views = @{
							@"name" : self.albumName,
							@"numImages" : self.numberOfImages,
							@"date" : self.date
							};
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[name]-5-[numImages]-15-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.albumName
																 attribute:NSLayoutAttributeLeft
																 relatedBy:NSLayoutRelationEqual
																	toItem:self.contentView
																 attribute:NSLayoutAttributeLeft
																multiplier:1.0
																  constant:20]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.albumName
																 attribute:NSLayoutAttributeRight
																 relatedBy:NSLayoutRelationLessThanOrEqual
																	toItem:self.contentView
																 attribute:NSLayoutAttributeRight
																multiplier:1.0
																  constant:-30]];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-20-[numImages]-[date]-20-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewToSameBase:self.date equalToView:self.numberOfImages]];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-5-[bg]-5-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:@{@"bg" : self.textUnderlay}]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.textUnderlay amount:0]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.textUnderlay
																 attribute:NSLayoutAttributeTop
																 relatedBy:NSLayoutRelationEqual
																	toItem:self.albumName
																 attribute:NSLayoutAttributeTop
																multiplier:1.0
																  constant:-5]];
	
	[self.cellDisclosure addConstraints:[NSLayoutConstraint constraintView:self.cellDisclosure toSize:CGSizeMake(28, 28)]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromRight:self.cellDisclosure amount:15]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintViewFromBottom:self.cellDisclosure amount:40]];
}

-(void)imageUpdated
{
	[self setupBgWithImage:self.albumData.categoryImage];
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
    if(!albumData) return;
    
    self.albumData = albumData;
    
    // Add up/down arrows in front of album name when Community extension active
//#if defined(DEBUG)
//    NSLog(@"setupWithAlbumData: usesCommunityPluginV29=%@, hasAdminRights=%@",
//          ([Model sharedInstance].usesCommunityPluginV29 ? @"YES" : @"NO"),
//          ([Model sharedInstance].hasAdminRights ? @"YES" : @"NO"));
//#endif
    if (![Model sharedInstance].usesCommunityPluginV29 ||
        [Model sharedInstance].hasAdminRights ||
        ![Model sharedInstance].hadOpenedSession) {
        self.albumName.text = self.albumData.name;
    } else if (self.albumData.hasUploadRights) {
        self.albumName.text = [NSString stringWithFormat:@"≥≤ %@", self.albumData.name];
    } else {
        self.albumName.text = [NSString stringWithFormat:@"≥ %@", self.albumData.name];
    }
    
    // Display number of images and sub-albums
    if (self.albumData.numberOfSubCategories == 0) {
        
        // There are no sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%ld %@",
                                    (long)self.albumData.numberOfImages,
                                    self.albumData.numberOfImages > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
        
    } else if (self.albumData.totalNumberOfImages == 0) {
        
        // There are no images but sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%ld %@",
                                    (long)self.albumData.numberOfSubCategories,
                                    self.albumData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
        
    } else {
        
        // There are images and sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%ld %@, %ld %@",
                                    (long)self.albumData.totalNumberOfImages,
                                    self.albumData.totalNumberOfImages > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo"),
                                    (long)self.albumData.numberOfSubCategories,
                                    self.albumData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
    }
    
    // Display date/time of last edition
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.formatterBehavior = NSDateFormatterBehavior10_4;
    formatter.dateStyle = NSDateFormatterShortStyle;
    self.date.text = [formatter stringFromDate:self.albumData.dateLast];
    
    // Display album image
    NSInteger imageSize = CGImageGetHeight(albumData.categoryImage.CGImage) * CGImageGetBytesPerRow(albumData.categoryImage.CGImage);
    
    if(albumData.categoryImage && imageSize > 0)
    {
        [self setupBgWithImage:albumData.categoryImage];
    }
    else if(albumData.albumThumbnailId > 0)
    {
        __weak typeof(self) weakSelf = self;
        self.cellDataRequest = [ImageService getImageInfoById:albumData.albumThumbnailId
                                             ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                                                 if(!imageData.MediumPath)
                                                 {
                                                     albumData.categoryImage = [UIImage imageNamed:@"placeholder"];
                                                 }
                                                 else
                                                 {
                                                     NSString *URLRequest = [NetworkHandler getURLWithPath:imageData.MediumPath asPiwigoRequest:NO withURLParams:nil];
                                                     
                                                     // Ensure that SSL certificates won't be rejected
                                                     AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
                                                     [policy setAllowInvalidCertificates:YES];
                                                     [policy setValidatesDomainName:NO];
                                                     
                                                     AFImageDownloader *dow = [AFImageDownloader defaultInstance];
                                                     [dow.sessionManager setSecurityPolicy:policy];
                                                     
                                                     [self.backgroundImage setImageWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:URLRequest]]
                                                                                 placeholderImage:[UIImage imageNamed:@"placeholder"]
                                                                                          success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                                                                              albumData.categoryImage = image;
                                                                                              [weakSelf setupBgWithImage:image];
                                                                                          } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
#if defined(DEBUG)
                                                                                              NSLog(@"fail to get imgage for album at %@", imageData.MediumPath);
#endif
                                                                                          }];
                                                 }
                                             } onFailure:^(NSURLSessionTask *task, NSError *error) {
#if defined(DEBUG)
                                                 NSLog(@"setupWithAlbumData — Fail to get album bg image: %@", [error localizedDescription]);
#endif
                                             }];
    }
}

-(void)setupBgWithImage:(UIImage*)image
{
    self.backgroundImage.image = image;
    
    if(!IS_OS_8_OR_LATER)
    {
        LEColorPicker *colorPicker = [LEColorPicker new];
        LEColorScheme *colorScheme = [colorPicker colorSchemeFromImage:image];
        UIColor *backgroundColor = colorScheme.backgroundColor;
        //    UIColor *primaryColor = colorScheme.primaryTextColor;
        //    UIColor *secondaryColor = colorScheme.secondaryTextColor;
        
        CGFloat bgRed = CGColorGetComponents(backgroundColor.CGColor)[0] * 255;
        CGFloat bgGreen = CGColorGetComponents(backgroundColor.CGColor)[1] * 255;
        CGFloat bgBlue = CGColorGetComponents(backgroundColor.CGColor)[2] * 255;
        
        
        int threshold = 105;
        int bgDelta = (bgRed * 0.299) + (bgGreen * 0.587) + (bgBlue * 0.114);
        UIColor *bgColor = (255 - bgDelta < threshold) ? [UIColor blackColor] : [UIColor whiteColor];
        self.textUnderlay.backgroundColor = bgColor;
        self.numberOfImages.textColor = (255 - bgDelta < threshold) ? [UIColor piwigoWhiteCream] : [UIColor piwigoGray];
        self.date.textColor = self.numberOfImages.textColor;
        self.cellDisclosure.tintColor = self.numberOfImages.textColor;
    }
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    
    [self.cellDataRequest cancel];
    [self.backgroundImage cancelImageDownloadTask];
    self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];
    
    self.albumName.text = @"";
    self.numberOfImages.text = @"";
}

-(void)setFrame:(CGRect)frame
{
    frame.size.height -= 8.0;
    [super setFrame:frame];
}


#pragma mark -- Move Category

-(void)moveCategory
{
    MoveCategoryViewController *moveCategoryVC = [[MoveCategoryViewController alloc] initWithSelectedCategory:self.albumData];
    if([self.cellDelegate respondsToSelector:@selector(pushView:)])
    {
        [self.cellDelegate pushView:moveCategoryVC];
    }
}


#pragma mark -- Rename Category

-(void)renameCategory
{
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"renameCategory_title", @"Rename Album")
                                message:[NSString stringWithFormat:@"%@ \"%@\":", NSLocalizedString(@"renameCategory_message", @"Enter a new name for this album"), self.albumData.name]
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"createNewAlbum_placeholder", @"Album Name");
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.delegate = self;
    }];

    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];

    self.categoryAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"renameCategory_button", @"Rename")
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction * action) {
            // Rename album if possible
            if(alert.textFields.firstObject.text.length > 0) {
                [self renameCategoryWithName:alert.textFields.firstObject.text andViewController:topViewController];
            }
        }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.categoryAction];
    [topViewController presentViewController:alert animated:YES completion:nil];
}

-(void)renameCategoryWithName:(NSString *)albumName andViewController:(UIViewController *)topViewController
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showCreateCategoryHUDwithLabel:NSLocalizedString(@"renameCategoryHUD_label", @"Renaming Album…") inView:topViewController.view];
    });
    
    // Rename album
    [AlbumService renameCategory:self.albumData.albumId
                         forName:albumName
                    OnCompletion:^(NSURLSessionTask *task, BOOL renamedSuccessfully) {
                        
                        if(renamedSuccessfully)
                        {
                            [self hideCreateCategoryHUDwithSuccess:YES inView:topViewController.view completion:^{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    self.albumData.name = albumName;
                                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
                                });
                            }];
                        }
                        else
                        {
                            [self hideCreateCategoryHUDwithSuccess:NO inView:topViewController.view completion:^{
                                [self showRenameErrorWithMessage:nil andViewController:topViewController];
                            }];
                        }
                    } onFailure:^(NSURLSessionTask *task, NSError *error) {
                        [self hideCreateCategoryHUDwithSuccess:NO inView:topViewController.view completion:^{
                            [self showRenameErrorWithMessage:[error localizedDescription] andViewController:topViewController];
                        }];
                    }];
}
    
-(void)showRenameErrorWithMessage:(NSString*)message andViewController:(UIViewController *)topViewController
{
	NSString *errorMessage = NSLocalizedString(@"renameCategoyError_message", @"Failed to rename your album");
	if(message)
	{
		errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
	}
    UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"renameCategoyError_title", @"Rename Fail")
                message:errorMessage
                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [topViewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark -- Delete Category

-(void)deleteCategory
{
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }

    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"deleteCategory_title", @"DELETE ALBUM")
        message:[NSString stringWithFormat:NSLocalizedString(@"deleteCategory_message", @"ARE YOU SURE YOU WANT TO DELETE THE ALBUM \"%@\" AND ALL %@ IMAGES?"), self.albumData.name, @(self.albumData.totalNumberOfImages)]
        preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* nextAlertAction = [UIAlertAction
         actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
         style:UIAlertActionStyleDestructive
         handler:^(UIAlertAction * action) {
             // Are you sure?
             UIAlertController* alert = [UIAlertController
                 alertControllerWithTitle:NSLocalizedString(@"deleteCategoryConfirm_title", @"Are you sure?")
                 message:[NSString stringWithFormat:NSLocalizedString(@"deleteCategoryConfirm_message", @"Please enter the number of images in order to delete this album\nNumber of images: %@"), @(self.albumData.numberOfImages)]
                 preferredStyle:UIAlertControllerStyleAlert];
             
             [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                 textField.placeholder = [NSString stringWithFormat:@"%@", @(self.albumData.numberOfImages)];
                 textField.clearButtonMode = UITextFieldViewModeAlways;
                 textField.keyboardType = UIKeyboardTypeNumberPad;
                 textField.delegate = self;
             }];
             
             UIAlertAction* defaultAction = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                        style:UIAlertActionStyleCancel
                        handler:^(UIAlertAction * action) {}];
             
             self.deleteAction = [UIAlertAction
                        actionWithTitle:NSLocalizedString(@"deleteCategoryConfirm_deleteButton", @"DELETE")
                        style:UIAlertActionStyleDestructive
                        handler:^(UIAlertAction * action) {
                            if(alert.textFields.firstObject.text.length > 0)
                            {
                                [self deleteCategoryWithNumberOfImages:[alert.textFields.firstObject.text integerValue] andViewController:topViewController];
                            }
                        }];
             
             [alert addAction:defaultAction];
             [alert addAction:self.deleteAction];
             [topViewController presentViewController:alert animated:YES completion:nil];
    }];
    
    [alert addAction:defaultAction];
    [alert addAction:nextAlertAction];
    [topViewController presentViewController:alert animated:YES completion:nil];
}

-(void)deleteCategoryWithNumberOfImages:(NSInteger)number andViewController:(UIViewController *)topViewController
{
    // Delete album?
    if(number == self.albumData.totalNumberOfImages)
    {
        // Display HUD during the update
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showCreateCategoryHUDwithLabel:NSLocalizedString(@"deleteCategoryHUD_label", @"Deleting Album…") inView:topViewController.view];
        });
        
        [AlbumService deleteCategory:self.albumData.albumId
                OnCompletion:^(NSURLSessionTask *task, BOOL deletedSuccessfully) {
                        if(deletedSuccessfully)
                        {
                            [self hideCreateCategoryHUDwithSuccess:YES inView:topViewController.view completion:^{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [[CategoriesData sharedInstance] deleteCategory:self.albumData.albumId];
                                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
                                });
                            }];
                        }
                        else
                        {
                            [self hideCreateCategoryHUDwithSuccess:NO inView:topViewController.view completion:^{
                                [self showDeleteCategoryErrorWithMessage:nil andViewController:topViewController];
                            }];
                        }
                }  onFailure:^(NSURLSessionTask *task, NSError *error) {
                    [self hideCreateCategoryHUDwithSuccess:NO inView:topViewController.view completion:^{
                        [self showDeleteCategoryErrorWithMessage:[error localizedDescription] andViewController:topViewController];
                    }];
                }];
    }
    else
    {    // User entered the wrong amount
        UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:NSLocalizedString(@"deleteCategoryMatchError_title", @"Number Doesn't Match")
                message:NSLocalizedString(@"deleteCategoryMatchError_message", @"The number of images you entered doesn't match the number of images in the category. Please try again if you desire to delete this album")
                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [topViewController presentViewController:alert animated:YES completion:nil];
    }
}

-(void)showDeleteCategoryErrorWithMessage:(NSString*)message andViewController:(UIViewController *)topViewController
{
	NSString *errorMessage = NSLocalizedString(@"deleteCategoryError_message", @"Failed to delete your album");
	if(message)
	{
		errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
	}

    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"deleteCategoryError_title", @"Delete Fail")
            message:errorMessage
            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [topViewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark -- HUD methods

-(void)showCreateCategoryHUDwithLabel:(NSString *)label inView:(UIView *)topView
{
    // Create the loading HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:topView];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:topView animated:YES];
    }
    
    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max) {
        hud.contentColor = [UIColor piwigoWhiteCream];
        hud.bezelView.color = [UIColor colorWithWhite:0.f alpha:1.0];
    } else {
        hud.contentColor = [UIColor piwigoGray];
        hud.bezelView.color = [UIColor piwigoGrayLight];
    }

    // Define the text
    hud.label.text = label;
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideCreateCategoryHUDwithSuccess:(BOOL)success inView:(UIView *)topView completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [MBProgressHUD HUDForView:topView];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"Complete", nil);
                [hud hideAnimated:YES afterDelay:3.f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}


#pragma mark -- UITextField Delegate Methods

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // Disable Add/Delete Category action
    [self.categoryAction setEnabled:NO];
    [self.deleteAction setEnabled:NO];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Enable Add/Delete Category action if text field not empty
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    [self.categoryAction setEnabled:(finalString.length >= 1)];
    [self.deleteAction setEnabled:(finalString.length >= 1)];
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    // Disable Add/Delete Category action
    [self.categoryAction setEnabled:NO];
    [self.deleteAction setEnabled:NO];
    return YES;
}

-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return YES;
}

@end
