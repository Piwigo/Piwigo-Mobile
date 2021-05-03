//
//  CategoryCollectionViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AlbumImagesViewController.h"
#import "AlbumTableViewCell.h"
#import "CategoriesData.h"
#import "CategoryCollectionViewCell.h"
#import "ImagesCollection.h"

@interface CategoryCollectionViewCell() <UITableViewDataSource, UITableViewDelegate, MGSwipeTableCellDelegate, SelectCategoryDelegate, UITextFieldDelegate>

@property (nonatomic, strong) PiwigoAlbumData *albumData;
@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) UIAlertAction *categoryAction;
@property (nonatomic, strong) UIAlertAction *deleteAction;

@end

@implementation CategoryCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.tableView = [UITableView new];
		self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.tableView.backgroundColor = [UIColor clearColor];
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [self.tableView registerNib:[UINib nibWithNibName:@"AlbumTableViewCell" bundle:nil] forCellReuseIdentifier:kAlbumTableCell_ID];
		self.tableView.delegate = self;
		self.tableView.dataSource = self;
		[self.contentView addSubview:self.tableView];
		[self.contentView addConstraints:[NSLayoutConstraint constraintFillSize:self.tableView]];
    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(categoriesUpdated:) name:kPiwigoNotificationChangedAlbumData object:nil];
	}
	return self;
}

-(void)setupWithAlbumData:(PiwigoAlbumData*)albumData
{
	self.albumData = albumData;
	[self.tableView reloadData];
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	
	self.albumData = nil;
}

-(void)categoriesUpdated:(NSNotification *)notification
{
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;

        // Right category Id?
        NSInteger catId = [[userInfo objectForKey:@"albumId"] integerValue];
        if (catId != self.albumData.albumId) return;

        // Add or remove thumbnail image?
        NSString *thumbnailUrl = [userInfo objectForKey:@"thumbnailUrl"];
        if (self.albumData.numberOfImages == 0) {
            self.albumData.categoryImage = nil;
            self.albumData.albumThumbnailId = 0;
            self.albumData.albumThumbnailUrl = nil;
        } else if (self.albumData.numberOfImages == 1) {
            NSInteger thumbnailId = [[userInfo objectForKey:@"thumbnailId"] intValue];
            self.albumData.albumThumbnailId = thumbnailId;
            self.albumData.albumThumbnailUrl = thumbnailUrl;
        }
        
        // Update number of images and thumbnail if needed
        [self.tableView reloadData];
    }
}

#pragma mark - UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 156.5;                    // see XIB file
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AlbumTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAlbumTableCell_ID forIndexPath:indexPath];
    if (!cell) {
        [tableView registerNib:[UINib nibWithNibName:@"AlbumTableViewCell" bundle:nil] forCellReuseIdentifier:kAlbumTableCell_ID];
        cell = [tableView dequeueReusableCellWithIdentifier:kAlbumTableCell_ID forIndexPath:indexPath];
    }

    cell.delegate = self;
	[cell setupWithAlbumData:self.albumData];
	
    cell.isAccessibilityElement = YES;
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
    // Push new album view
    if([self.categoryDelegate respondsToSelector:@selector(pushCategoryView:)])
	{
		AlbumImagesViewController *albumView = [[AlbumImagesViewController alloc] initWithAlbumId:self.albumData.albumId inCache:YES];
		[self.categoryDelegate pushCategoryView:albumView];
	}
}


#pragma mark - MGSwipeTableCellDelegate Methods

-(BOOL)swipeTableCell:(MGSwipeTableCell*) cell canSwipe:(MGSwipeDirection) direction fromPoint:(CGPoint)point;
{
    return YES;
}

-(NSArray*) swipeTableCell:(MGSwipeTableCell*) cell swipeButtonsForDirection:(MGSwipeDirection)direction
             swipeSettings:(MGSwipeSettings*) swipeSettings expansionSettings:(MGSwipeExpansionSettings*) expansionSettings
{
    // Only admins can rename, move and delete albums
    if (![Model sharedInstance].hasAdminRights) { return nil; }
    
    // Settings
    cell.swipeBackgroundColor = [UIColor piwigoColorOrange];
    swipeSettings.transition = MGSwipeTransitionBorder;
    expansionSettings.buttonIndex = 0;

    // Right => Left swipe
    if (direction == MGSwipeDirectionRightToLeft) {
        MGSwipeButton *trash = [MGSwipeButton buttonWithTitle:@""
                                                         icon:[UIImage imageNamed:@"swipeTrash.png"]
                                              backgroundColor:[UIColor redColor]
                                                     callback:^BOOL(MGSwipeTableCell *sender) {
            [self deleteCategory];
            return NO;
        }];
        MGSwipeButton *move = [MGSwipeButton buttonWithTitle:@""
                                                        icon:[UIImage imageNamed:@"swipeMove.png"]
                                             backgroundColor:[UIColor piwigoColorBrown]
                                                    callback:^BOOL(MGSwipeTableCell *sender) {
            [self moveCategory];
            return NO;
        }];
        MGSwipeButton *rename = [MGSwipeButton buttonWithTitle:@""
                                                          icon:[UIImage imageNamed:@"swipeRename.png"]
                                               backgroundColor:[UIColor piwigoColorOrange]
                                                      callback:^BOOL(MGSwipeTableCell *sender) {
            [self renameCategory];
            return NO;
        }];
        return @[trash, move, rename];
    }
    else {
        // Disabled because it does not work reliably on the server side
//        if (self.albumData.numberOfImages > 0) {
//            MGSwipeButton *refresh = [MGSwipeButton buttonWithTitle:@""
//                                                               icon:[UIImage imageNamed:@"SwipeRefresh.png"]
//                                                        backgroundColor:[UIColor blueColor]
//                                                           callback:^BOOL(MGSwipeTableCell *sender) {
//                [self resfreshRepresentative];
//                return YES;
//            }];
//            return @[refresh];
//        }
    }
    return nil;
}


#pragma mark - Move Category

-(void)moveCategory
{
    UIStoryboard *moveSB = [UIStoryboard storyboardWithName:@"SelectCategoryViewController" bundle:nil];
    SelectCategoryViewController *moveVC = [moveSB instantiateViewControllerWithIdentifier:@"SelectCategoryViewController"];
    [moveVC setInputWithParameter:self.albumData for:kPiwigoCategorySelectActionMoveAlbum];
    moveVC.delegate = self;
    if([self.categoryDelegate respondsToSelector:@selector(pushCategoryView:)])
    {
        [self.categoryDelegate pushCategoryView:moveVC];
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
        handler:^(UIAlertAction * action) {
            // Hide swipe buttons
            AlbumTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            [cell hideSwipeAnimated:YES];
    }];

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
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)renameCategoryWithName:(NSString *)albumName comment:(NSString *)albumComment andViewController:(UIViewController *)topViewController
{
    // Display HUD during the update
    [topViewController showPiwigoHUDWithTitle:NSLocalizedString(@"renameCategoryHUD_label", @"Renaming Album…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
    
    // Rename album
    [AlbumService renameCategory:self.albumData.albumId
                         forName:albumName
                     withComment:albumComment
                    OnCompletion:^(NSURLSessionTask *task, BOOL renamedSuccessfully) {
                        
                        if(renamedSuccessfully)
                        {
                            [topViewController updatePiwigoHUDwithSuccessWithCompletion:^{
                                [topViewController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        self.albumData.name = albumName;
                                        self.albumData.comment = albumComment;
                                        
                                        // Notify album/image view of modification
                                        [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];

                                        // Hide swipe buttons
                                        AlbumTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
                                        [cell hideSwipeAnimated:YES];
                                    });
                                }];
                            }];
                        }
                        else
                        {
                            [topViewController hidePiwigoHUDWithCompletion:^{
                                [topViewController dismissPiwigoErrorWithTitle:NSLocalizedString(@"renameCategoyError_title", @"Rename Fail") message:NSLocalizedString(@"renameCategoyError_message", @"Failed to rename your album") errorMessage:@"" completion:^{ }];
                            }];
                        }
                    } onFailure:^(NSURLSessionTask *task, NSError *error) {
                        [topViewController hidePiwigoHUDWithCompletion:^{
                            [topViewController dismissPiwigoErrorWithTitle:NSLocalizedString(@"renameCategoyError_title", @"Rename Fail") message:NSLocalizedString(@"renameCategoyError_message", @"Failed to rename your album") errorMessage:[error localizedDescription] completion:^{ }];
                        }];
                    }];
}


#pragma mark - Refresh Representative

//-(void)resfreshRepresentative
//{
//    // Determine the present view controller
//    UIViewController *topViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
//    while (topViewController.presentedViewController) {
//        topViewController = topViewController.presentedViewController;
//    }
//
//    // Display HUD during the update
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [self showHUDwithLabel:NSLocalizedString(@"refreshCategoryHUD_label", @"Refreshing Representative…") inView:topViewController.view];
//    });
//
//    // Refresh album representative
//    [AlbumService refreshCategoryRepresentativeForCategory:self.albumData.albumId
//          OnCompletion:^(NSURLSessionTask *task, BOOL refreshedSuccessfully) {
//              if (refreshedSuccessfully)
//              {
//                  [self hideHUDwithSuccess:YES inView:topViewController.view completion:^{
//                      dispatch_async(dispatch_get_main_queue(), ^{
//                          [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationCategoryDataUpdated object:nil];
//
//                          // Hide swipe buttons
//                          AlbumTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathWithIndex:0]];
//                          [cell hideSwipeAnimated:YES];
//                      });
//                  }];
//              }
//              else
//              {
//                  [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
//                      [self showRefreshErrorWithMessage:nil andViewController:topViewController];
//                  }];
//              }
//          } onFailure:^(NSURLSessionTask *task, NSError *error) {
//              [self hideHUDwithSuccess:NO inView:topViewController.view completion:^{
//                  [self showRefreshErrorWithMessage:[error localizedDescription] andViewController:topViewController];
//              }];
//          }
//    ];
//}

//-(void)showRefreshErrorWithMessage:(NSString*)message andViewController:(UIViewController *)topViewController
//{
//    NSString *errorMessage = NSLocalizedString(@"refreshCategoyError_message", @"Failed to refresh your album representative");
//    if(message)
//    {
//        errorMessage = [NSString stringWithFormat:@"%@\n%@", errorMessage, message];
//    }
//    UIAlertController* alert = [UIAlertController
//                                alertControllerWithTitle:NSLocalizedString(@"refreshCategoyError_title", @"Refresh Fail")
//                                message:errorMessage
//                                preferredStyle:UIAlertControllerStyleActionSheet];
//
//    UIAlertAction* defaultAction = [UIAlertAction
//                                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
//                                    style:UIAlertActionStyleCancel
//                                    handler:^(UIAlertAction * action) {}];
//
//    // Add actions
//    [alert addAction:defaultAction];
//
//    // Present list of actions
//    alert.view.tintColor = UIColor.piwigoColorOrange;
//    if (@available(iOS 13.0, *)) {
//        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
//    } else {
//        // Fallback on earlier versions
//    }
//    alert.popoverPresentationController.sourceView = self.contentView;
//    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUnknown;
//    alert.popoverPresentationController.sourceRect = self.contentView.frame;
//    [topViewController presentViewController:alert animated:YES completion:^{
//        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
//        alert.view.tintColor = UIColor.piwigoColorOrange;
//    }];
//}


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
        handler:^(UIAlertAction * action) {
            // Hide swipe buttons
            AlbumTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            [cell hideSwipeAnimated:YES];
    }];
    
    UIAlertAction* emptyCategoryAction = [UIAlertAction
       actionWithTitle:NSLocalizedString(@"deleteCategory_empty", @"Delete Empty Album")
       style:UIAlertActionStyleDestructive
       handler:^(UIAlertAction * action) {
           [self deleteCategoryWithNumberOfImages:0  deletionMode:kCategoryDeletionModeNone andViewController:topViewController];
    }];
    
    UIAlertAction* keepImagesAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"deleteCategory_noImages", @"Keep Images")
        style:UIAlertActionStyleDefault
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
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    alert.popoverPresentationController.sourceView = self.contentView;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUnknown;
    alert.popoverPresentationController.sourceRect = self.contentView.frame;
    [topViewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
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
    alert.view.tintColor = UIColor.piwigoColorOrange;
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [topViewController presentViewController:alert animated:YES completion:^{
        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
        alert.view.tintColor = UIColor.piwigoColorOrange;
    }];
}

-(void)deleteCategoryWithNumberOfImages:(NSInteger)number deletionMode:(NSString *)deletionMode andViewController:(UIViewController *)topViewController
{
    // Delete album?
    if(number == self.albumData.totalNumberOfImages)
    {
        // Display HUD during the update
        [topViewController showPiwigoHUDWithTitle:NSLocalizedString(@"deleteCategoryHUD_label", @"Deleting Album…") detail:@"" buttonTitle:@"" buttonTarget:nil buttonSelector:nil inMode:MBProgressHUDModeIndeterminate];
        
        [AlbumService deleteCategory:self.albumData.albumId
                      inMode:deletionMode
                OnCompletion:^(NSURLSessionTask *task, BOOL deletedSuccessfully) {
                        if(deletedSuccessfully)
                        {
                            [topViewController updatePiwigoHUDwithSuccessWithCompletion:^{
                                [topViewController hidePiwigoHUDAfterDelay:kDelayPiwigoHUD completion:^{
                                    // Delete category from cache
                                    [[CategoriesData sharedInstance] deleteCategory:self.albumData.albumId];

                                    // Notify the Upload database that this category has been deleted
                                    NSDictionary *userInfo = @{@"albumId" : @(self.albumData.albumId)};
                                    [[NSNotificationCenter defaultCenter] postNotificationName:kPiwigoNotificationDeletedCategory object:nil userInfo:userInfo];

                                    // Hide swipe buttons
                                    AlbumTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
                                    [cell hideSwipeAnimated:YES];
                                }];
                            }];
                        }
                        else
                        {
                            [topViewController hidePiwigoHUDWithCompletion:^{
                                [topViewController dismissPiwigoErrorWithTitle:NSLocalizedString(@"deleteCategoryError_title", @"Delete Fail") message:NSLocalizedString(@"deleteCategoryError_message", @"Failed to delete your album") errorMessage:@"" completion:^{ }];
                            }];
                        }
                }  onFailure:^(NSURLSessionTask *task, NSError *error) {
                    [topViewController hidePiwigoHUDWithCompletion:^{
                        [topViewController dismissPiwigoErrorWithTitle:NSLocalizedString(@"deleteCategoryError_title", @"Delete Fail") message:NSLocalizedString(@"deleteCategoryError_message", @"Failed to delete your album") errorMessage:[error localizedDescription] completion:^{ }];
                    }];
                }];
    }
    else
    {    // User entered the wrong amount
        [topViewController dismissPiwigoErrorWithTitle:NSLocalizedString(@"deleteCategoryMatchError_title", @"Number Doesn't Match") message:NSLocalizedString(@"deleteCategoryMatchError_message", @"The number of images you entered doesn't match the number of images in the category. Please try again if you desire to delete this album") errorMessage:@"" completion:^{ }];
    }
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


#pragma mark - SelectCategoryDelegate Methods

-(void)didSelectCategoryWithId:(NSInteger)category
{
    AlbumTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    [cell hideSwipeAnimated:YES];
}

@end
