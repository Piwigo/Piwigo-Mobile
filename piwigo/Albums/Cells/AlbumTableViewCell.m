//
//  AlbumTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumService.h"
#import "AlbumTableViewCell.h"
#import "CategoriesData.h"
#import "ImageService.h"
#import "LEColorPicker.h"
#import "MBProgressHUD.h"
#import "Model.h"
#import "MoveCategoryViewController.h"
#import "NetworkHandler.h"
#import "PiwigoAlbumData.h"
#import "SAMKeychain.h"

NSString * const kAlbumTableCell_ID = @"AlbumTableViewCell";

@interface AlbumTableViewCell() <UITextFieldDelegate>

@property (nonatomic, strong) UIAlertAction *categoryAction;
@property (nonatomic, strong) UIAlertAction *deleteAction;

@end

@implementation AlbumTableViewCell

-(void)imageUpdated
{
    self.backgroundImage.image = self.albumData.categoryImage;
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
    if(!albumData) return;
    
    self.albumData = albumData;
    
    // General settings
    self.backgroundColor = [UIColor piwigoColorBackground];
    self.contentView.layer.cornerRadius = 14;
    self.contentView.backgroundColor = [UIColor piwigoColorCellBackground];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.topCut.layer.cornerRadius = 7;
    self.topCut.backgroundColor = [UIColor piwigoColorBackground];
    self.bottomCut.layer.cornerRadius = 7;
    self.bottomCut.backgroundColor = [UIColor piwigoColorBackground];

    // Album name
    self.albumName.text = self.albumData.name;
    self.albumName.font = [UIFont piwigoFontButton];
    self.albumName.textColor = [UIColor piwigoColorOrange];
    self.albumName.font = [self.albumName.font fontWithSize:[UIFont fontSizeForLabel:self.albumName nberLines:2]];

    // Album comment
    if (self.albumData.comment.length == 0) {
        if([Model sharedInstance].hasAdminRights) {
            self.albumComment.text = [NSString stringWithFormat:@"(%@)", NSLocalizedString(@"createNewAlbumDescription_noDescription", @"no description")];
            self.albumComment.textColor = [UIColor piwigoColorRightLabel];
        } else {
            self.albumComment.text = @"";
        }
    }
    else {
        self.albumComment.text = self.albumData.comment;
        self.albumComment.textColor = [UIColor piwigoColorText];
    }
    self.albumComment.font = [UIFont piwigoFontSmall];
    self.albumComment.font = [self.albumComment.font fontWithSize:[UIFont fontSizeForLabel:self.albumComment nberLines:3]];

    // Number of images and sub-albums
    self.numberOfImages.font = [UIFont piwigoFontTiny];
    self.numberOfImages.textColor = [UIColor piwigoColorText];
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setPositiveFormat:@"#,##0"];
    if (self.albumData.numberOfSubCategories == 0) {
        
        // There are no sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@",
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfImages]],
                                    self.albumData.numberOfImages > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo")];
        
    } else if (self.albumData.totalNumberOfImages == 0) {
        
        // There are no images but sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@",
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfSubCategories]],
                                    self.albumData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
        
    } else {
        
        // There are images and sub-albums
        self.numberOfImages.text = [NSString stringWithFormat:@"%@ %@, %@ %@",
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.totalNumberOfImages]],
                                    self.albumData.totalNumberOfImages > 1 ? NSLocalizedString(@"categoryTableView_photosCount", @"photos") : NSLocalizedString(@"categoryTableView_photoCount", @"photo"),
                                    [numberFormatter stringFromNumber:[NSNumber numberWithInteger:self.albumData.numberOfSubCategories]],
                                    self.albumData.numberOfSubCategories > 1 ? NSLocalizedString(@"categoryTableView_subCategoriesCount", @"sub-albums") : NSLocalizedString(@"categoryTableView_subCategoryCount", @"sub-album")];
    }
    self.numberOfImages.font = [self.numberOfImages.font fontWithSize:[UIFont fontSizeForLabel:self.numberOfImages nberLines:1]];

    // Add renaming, moving and deleting capabilities when user has admin rights
    if([Model sharedInstance].hasAdminRights)
    {
        // Handle
        self.handleButton.layer.cornerRadius = 7;
        self.handleButton.backgroundColor = [UIColor piwigoColorOrange];
        self.handleButton.hidden = NO;

        // Right => Left swipe
        self.swipeBackgroundColor = [UIColor piwigoColorOrange];
        self.rightSwipeSettings.transition = MGSwipeTransitionBorder;
        self.rightButtons = @[[MGSwipeButton buttonWithTitle:@""
                                                        icon:[UIImage imageNamed:@"swipeTrash.png"]
                                             backgroundColor:[UIColor redColor]
                                                    callback:^BOOL(MGSwipeTableCell *sender) {
                                                        [self deleteCategory];
                                                        return YES;
                                                    }],
                              [MGSwipeButton buttonWithTitle:@""
                                                      icon:[UIImage imageNamed:@"swipeMove.png"]
                                           backgroundColor:[UIColor piwigoColorBrown]
                                                  callback:^BOOL(MGSwipeTableCell *sender) {
                                                      [self moveCategory];
                                                      return YES;
                                                  }],
                              [MGSwipeButton buttonWithTitle:@""
                                                        icon:[UIImage imageNamed:@"swipeRename.png"]
                                             backgroundColor:[UIColor piwigoColorOrange]
                                                    callback:^BOOL(MGSwipeTableCell *sender) {
                                                        [self renameCategory];
                                                        return YES;
                                                    }]
                               ];
  
        // Left => Right swipe (only if there are images in the album)
        // Disabled because it does not work reliably on the server side
//        if (self.albumData.numberOfImages > 0) {
//
//            self.leftSwipeSettings.transition = MGSwipeTransitionBorder;
//            self.leftButtons = @[[MGSwipeButton buttonWithTitle:@""
//                                                           icon:[UIImage imageNamed:@"SwipeRefresh.png"]
//                                                backgroundColor:[UIColor blueColor]
//                                                       callback:^BOOL(MGSwipeTableCell *sender) {
//                                                           [self resfreshRepresentative];
//                                                           return YES;
//                                                       }]];
//        }
    }
    
    // Display album image
    self.backgroundImage.layer.cornerRadius = 10;
    NSInteger imageSize = CGImageGetHeight(albumData.categoryImage.CGImage) * CGImageGetBytesPerRow(albumData.categoryImage.CGImage);
    
    if (albumData.categoryImage && imageSize > 0)
    {
        // Album thumbnail in memory
        self.backgroundImage.image = albumData.categoryImage;
    }
    else if (albumData.albumThumbnailUrl.length <= 0)
    {
        // No album thumbnail
        albumData.categoryImage = [UIImage imageNamed:@"placeholder"];
        self.backgroundImage.image = [UIImage imageNamed:@"placeholder"];
        return;
    }
    else
    {
        // Load album thumbnail
        __weak typeof(self) weakSelf = self;
        NSURL *URL = [NSURL URLWithString:albumData.albumThumbnailUrl];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        [self.backgroundImage setImageWithURLRequest:request
                                    placeholderImage:[UIImage imageNamed:@"placeholder"]
                                             success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                                 albumData.categoryImage = image;
                                                 weakSelf.backgroundImage.image = image;
                                             }
                                             failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
#if defined(DEBUG)
                                                 NSLog(@"setupWithAlbumData — Fail to get album bg image for album at %@", albumData.albumThumbnailUrl);
#endif
                                             }];
    }
}


-(void)prepareForReuse
{
    [super prepareForReuse];
    
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


#pragma mark - Move Category

-(void)moveCategory
{
    MoveCategoryViewController *moveCategoryVC = [[MoveCategoryViewController alloc] initWithSelectedCategory:self.albumData];
    if([self.cellDelegate respondsToSelector:@selector(pushView:)])
    {
        [self.cellDelegate pushView:moveCategoryVC];
    }
}


#pragma mark - Rename Category

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
        textField.text = self.albumData.name;
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
        textField.delegate = self;
    }];

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"createNewAlbumDescription_placeholder", @"Description");
        textField.text = self.albumData.comment;
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        textField.autocorrectionType = UITextAutocorrectionTypeYes;
        textField.returnKeyType = UIReturnKeyContinue;
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
                [self renameCategoryWithName:alert.textFields.firstObject.text comment:alert.textFields.lastObject.text andViewController:topViewController];
            }
        }];
    
    [alert addAction:cancelAction];
    [alert addAction:self.categoryAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:nil];
}

-(void)renameCategoryWithName:(NSString *)albumName comment:(NSString *)albumComment andViewController:(UIViewController *)topViewController
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithLabel:NSLocalizedString(@"renameCategoryHUD_label", @"Renaming Album…") inView:topViewController.view];
    });
    
    // Rename album
    [AlbumService renameCategory:self.albumData.albumId
                         forName:albumName
                     withComment:albumComment
                    OnCompletion:^(NSURLSessionTask *task, BOOL renamedSuccessfully) {
                        
                        if(renamedSuccessfully)
                        {
                            [self hideHUDwithSuccess:YES inView:topViewController.view completion:^{
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    self.albumData.name = albumName;
                                    self.albumData.comment = albumComment;
                                    
                                    // Notify album/image view of modification
                                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
                                });
                            }];
                        }
                        else
                        {
                            [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                                [self showRenameErrorWithMessage:nil andViewController:topViewController];
                            }];
                        }
                    } onFailure:^(NSURLSessionTask *task, NSError *error) {
                        [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
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
                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* defaultAction = [UIAlertAction
                actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                style:UIAlertActionStyleCancel
                handler:^(UIAlertAction * action) {}];
    
    // Add actions
    [alert addAction:defaultAction];

    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.sourceView = self.contentView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUnknown;
    alert.popoverPresentationController.sourceRect = self.contentView.frame;
    [topViewController presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Refresh Representative

-(void)resfreshRepresentative
{
    // Determine the present view controller
    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showHUDwithLabel:NSLocalizedString(@"refreshCategoryHUD_label", @"Refreshing Representative…") inView:topViewController.view];
    });
    
    // Refresh album representative
    [AlbumService refreshCategoryRepresentativeForCategory:self.albumData.albumId
          OnCompletion:^(NSURLSessionTask *task, BOOL refreshedSuccessfully) {
              if (refreshedSuccessfully)
              {
                  [self hideHUDwithSuccess:YES inView:topViewController.view completion:^{
                      dispatch_async(dispatch_get_main_queue(), ^{
                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
                      });
                  }];
              }
              else
              {
                  [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                      [self showRefreshErrorWithMessage:nil andViewController:topViewController];
                  }];
              }
          } onFailure:^(NSURLSessionTask *task, NSError *error) {
              [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                  [self showRefreshErrorWithMessage:[error localizedDescription] andViewController:topViewController];
              }];
          }
    ];
}

-(void)showRefreshErrorWithMessage:(NSString*)message andViewController:(UIViewController *)topViewController
{
    NSString *errorMessage = NSLocalizedString(@"refreshCategoyError_message", @"Failed to refresh your album representative");
    if(message)
    {
        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
    }
    UIAlertController* alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"refreshCategoyError_title", @"Refresh Fail")
                                message:errorMessage
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* defaultAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                                    style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction * action) {}];
    
    // Add actions
    [alert addAction:defaultAction];

    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.sourceView = self.contentView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUnknown;
    alert.popoverPresentationController.sourceRect = self.contentView.frame;
    [topViewController presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Delete Category

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
        preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
        style:UIAlertActionStyleCancel
        handler:^(UIAlertAction * action) {}];
    
    UIAlertAction* emptyCategoryAction = [UIAlertAction
       actionWithTitle:NSLocalizedString(@"deleteCategory_empty", @"Delete Empty Album")
       style:UIAlertActionStyleDestructive
       handler:^(UIAlertAction * action) {
           [self deleteCategoryWithNumberOfImages:0  deletionMode:kCategoryDeletionModeNone andViewController:topViewController];
    }];
    
    UIAlertAction* keepImagesAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"deleteCategory_noImages", @"Keep Images")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {
            [self confirmCategoryDeletionWithNumberOfImages:self.albumData.totalNumberOfImages deletionMode:kCategoryDeletionModeNone andViewController:topViewController];
    }];

    UIAlertAction* orphanImagesAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"deleteCategory_orphanedImages", @"Delete Orphans")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {
            [self confirmCategoryDeletionWithNumberOfImages:self.albumData.totalNumberOfImages deletionMode:kCategoryDeletionModeOrphaned andViewController:topViewController];
    }];

    UIAlertAction* allImagesAction = [UIAlertAction
        actionWithTitle:self.albumData.totalNumberOfImages > 1 ? [NSString stringWithFormat:NSLocalizedString(@"deleteCategory_allImages", @"Delete %@ Images"), @(self.albumData.totalNumberOfImages)] : NSLocalizedString(@"deleteSingleImage_title", @"Delete Image")
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction * action) {
            [self confirmCategoryDeletionWithNumberOfImages:self.albumData.totalNumberOfImages deletionMode:kCategoryDeletionModeAll andViewController:topViewController];
     }];

    // Add actions
    switch (self.albumData.totalNumberOfImages) {
        case 0:
            [alert addAction:cancelAction];
            [alert addAction:emptyCategoryAction];
            break;
            
        default:
            [alert addAction:cancelAction];
            [alert addAction:keepImagesAction];
            [alert addAction:orphanImagesAction];
            [alert addAction:allImagesAction];
            break;
    }
    
    // Present list of actions
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.sourceView = self.contentView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUnknown;
    alert.popoverPresentationController.sourceRect = self.contentView.frame;
    [topViewController presentViewController:alert animated:YES completion:nil];
}

-(void)confirmCategoryDeletionWithNumberOfImages:(NSInteger)number deletionMode:(NSString *)deletionMode andViewController:(UIViewController *)topViewController
{
    // Are you sure?
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"deleteCategoryConfirm_title", @"Are you sure?")
               message:[NSString stringWithFormat:NSLocalizedString(@"deleteCategoryConfirm_message", @"Please enter the number of images in order to delete this album\nNumber of images: %@"), @(self.albumData.totalNumberOfImages)]
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = [NSString stringWithFormat:@"%@", @(self.albumData.numberOfImages)];
        textField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
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
                                 [self deleteCategoryWithNumberOfImages:[alert.textFields.firstObject.text integerValue]  deletionMode:deletionMode andViewController:topViewController];
                             }
                         }];
    
    [alert addAction:defaultAction];
    [alert addAction:self.deleteAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:nil];
}

-(void)deleteCategoryWithNumberOfImages:(NSInteger)number deletionMode:(NSString *)deletionMode andViewController:(UIViewController *)topViewController
{
    // Delete album?
    if(number == self.albumData.totalNumberOfImages)
    {
        // Display HUD during the update
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showHUDwithLabel:NSLocalizedString(@"deleteCategoryHUD_label", @"Deleting Album…") inView:topViewController.view];
        });
        
        [AlbumService deleteCategory:self.albumData.albumId
                      inMode:deletionMode
                OnCompletion:^(NSURLSessionTask *task, BOOL deletedSuccessfully) {
                        if(deletedSuccessfully)
                        {
                            [self hideHUDwithSuccess:YES inView:topViewController.view completion:^{
                                // Delete category from cache
                                [[CategoriesData sharedInstance] deleteCategory:self.albumData.albumId];
                            }];
                        }
                        else
                        {
                            [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
                                [self showDeleteCategoryErrorWithMessage:nil andViewController:topViewController];
                            }];
                        }
                }  onFailure:^(NSURLSessionTask *task, NSError *error) {
                    [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
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
        
        // Add actions
        [alert addAction:defaultAction];

        // Present list of actions
        if (@available(iOS 13.0, *)) {
            alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
        } else {
            // Fallback on earlier versions
        }
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
            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* defaultAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
            style:UIAlertActionStyleCancel
            handler:^(UIAlertAction * action) {}];
    
    // Add actions
    [alert addAction:defaultAction];

    // Present list of actions
    alert.popoverPresentationController.sourceView = self.contentView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUnknown;
    alert.popoverPresentationController.sourceRect = self.contentView.frame;
    [topViewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark - HUD methods

-(void)showHUDwithLabel:(NSString *)label inView:(UIView *)topView
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
    hud.contentColor = [UIColor piwigoColorHudContent];
    hud.bezelView.color = [UIColor piwigoColorHudBezelView];

    // Define the text
    hud.label.text = label;
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideHUDwithSuccess:(BOOL)success inView:(UIView *)topView completion:(void (^)(void))completion
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
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
                [hud hideAnimated:YES afterDelay:0.5f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}


#pragma mark - UITextField Delegate Methods

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
