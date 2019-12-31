//
//  EditImageParamsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "EditImageDatePickerTableViewCell.h"
#import "EditImageFilenameCollectionViewCell.h"
#import "EditImageParamsViewController.h"
#import "EditImagePrivacyTableViewCell.h"
#import "EditImageTagsTableViewCell.h"
#import "EditImageTextFieldTableViewCell.h"
#import "EditImageTextViewTableViewCell.h"
#import "ImageDetailViewController.h"
#import "ImageUpload.h"
#import "ImageService.h"
#import "ImagesCollection.h"
#import "MBProgressHUD.h"
#import "PiwigoTagData.h"
#import "SelectPrivacyViewController.h"
#import "TagsData.h"
#import "TagsViewController.h"
#import "UploadService.h"

CGFloat const kEditImageParamsViewWidth = 512.0;

typedef enum {
	EditImageParamsOrderImageName,
	EditImageParamsOrderAuthor,
    EditImageParamsOrderDate,
    EditImageParamsOrderDatePicker,
	EditImageParamsOrderPrivacy,
	EditImageParamsOrderTags,
	EditImageParamsOrderDescription,
	EditImageParamsOrderCount
} EditImageParamsOrder;

@interface EditImageParamsViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITextViewDelegate, EditImageFilenameDelegate, EditImageDatePickerDelegate, SelectPrivacyDelegate, TagsViewControllerDelegate>

@property (nonatomic, strong) PiwigoImageData *commonParameters;
@property (nonatomic, weak)   IBOutlet UITableView *editImageParamsTableView;
@property (nonatomic, weak)   IBOutlet UICollectionView *editImageThumbnailCollectionView;
@property (nonatomic, strong) NSMutableArray<PiwigoImageData *> *imagesToUpdate;

@property (nonatomic, assign) BOOL hasDatePicker;
@property (nonatomic, assign) BOOL shouldUpdateTitle;
@property (nonatomic, assign) BOOL shouldUpdateAuthor;
@property (nonatomic, assign) BOOL shouldUpdateDateCreated;
@property (nonatomic, strong) NSDate *oldCreationDate;
@property (nonatomic, assign) BOOL shouldUpdatePrivacyLevel;
@property (nonatomic, assign) BOOL shouldUpdateTags;
@property (nonatomic, assign) BOOL shouldUpdateComment;

@end

@implementation EditImageParamsViewController

-(void)awakeFromNib
{
	[super awakeFromNib];
	
    self.title = NSLocalizedString(@"imageDetailsView_title", @"Properties");
	
    // Buttons
    UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEdit)];
    [cancel setAccessibilityIdentifier:@"Cancel"];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEdit)];
    [done setAccessibilityIdentifier:@"Done"];

    // Navigation bar
    self.navigationController.navigationBarHidden = NO;
    self.navigationItem.leftBarButtonItem = cancel;
    self.navigationItem.rightBarButtonItem = done;

    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyColorPalette) name:kPiwigoNotificationPaletteChanged object:nil];
}

#pragma mark - View Lifecycle

-(void)applyColorPalette
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];

    // Navigation bar
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    self.navigationController.navigationBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];

    // Collection view
    self.editImageThumbnailCollectionView.backgroundColor = [UIColor piwigoCellBackgroundColor];
    [self.editImageThumbnailCollectionView reloadData];
    
    // Table view
    self.editImageParamsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    self.editImageParamsTableView.backgroundColor = [UIColor piwigoBackgroundColor];
    [self.editImageParamsTableView reloadData];
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    // Register date picker
    [self.editImageParamsTableView registerNib:[UINib nibWithNibName:@"EditImageDatePickerTableViewCell" bundle:nil] forCellReuseIdentifier:kDatePickerTableCell_ID];
    self.hasDatePicker = NO;

    // Initialise common image properties from first supplied image
    self.commonParameters = [PiwigoImageData new];
    self.commonParameters.imageTitle = self.images[0].imageTitle;
    self.commonParameters.author = self.images[0].author;
    self.commonParameters.dateCreated = self.images[0].dateCreated;
    self.commonParameters.privacyLevel = self.images[0].privacyLevel;
    self.commonParameters.tags = [NSArray arrayWithArray:self.images[0].tags];
    self.commonParameters.comment = self.images[0].comment;

    // Common title?
    for (PiwigoImageData *imageData in self.images) {
        // Keep title of first image if identical
        if ([self.commonParameters.imageTitle isEqualToString:imageData.imageTitle]) continue;
        
        // Images titles are different
        self.commonParameters.imageTitle = @"";
        break;
    }
    self.shouldUpdateTitle = NO;

    // Common author?
    for (PiwigoImageData *imageData in self.images) {
        // Keep author of first image if identical
        if ([self.commonParameters.author isEqualToString:imageData.author]) continue;
        
        // Images authors are different
        self.commonParameters.author = @"";
        break;
    }
    self.shouldUpdateAuthor = NO;

    // Common creation date is date of first image (can be nil)
    if (self.commonParameters.dateCreated == nil) {
        self.oldCreationDate = nil;
    } else {
        self.oldCreationDate = self.commonParameters.dateCreated;
    }
    self.shouldUpdateDateCreated = NO;
    
    // Common privacy?
    for (PiwigoImageData *imageData in self.images) {
        // Keep privacy of first image if identical
        if (self.commonParameters.privacyLevel == imageData.privacyLevel) continue;
        
        // Images privacy levels are different, display no level
        self.commonParameters.privacyLevel = NSNotFound;
        break;
    }
    self.shouldUpdatePrivacyLevel = NO;

    // Common tags?
    NSMutableArray *newTags = [[NSMutableArray alloc] initWithArray:self.commonParameters.tags];
    for (PiwigoImageData *imageData in self.images) {
        // Loop over the common tags
        NSMutableArray *tempTagList = [[NSMutableArray alloc] initWithArray:newTags];
        for (PiwigoTagData *tag in tempTagList) {
            // Remove tags not belonging to other images
            if (![[TagsData sharedInstance] listOfTags:imageData.tags containsTag:tag]) [newTags removeObject:tag];
            // Done if empty list
            if (newTags.count == 0) break;
        }
        // Done if empty list
        if (newTags.count == 0) break;
    }
    self.commonParameters.tags = newTags;
    self.shouldUpdateTags = NO;
    
    // Common comment?
    for (PiwigoImageData *imageData in self.images) {
        // Keep comment of first image if identical
        if ([self.commonParameters.comment isEqualToString:imageData.comment]) continue;
        
        // Images comments are different, display no comment
        self.commonParameters.comment = @"";
        break;
    }
    self.shouldUpdateComment = NO;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    // Adjust content inset
    // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
    CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
    CGFloat tableHeight = self.editImageParamsTableView.bounds.size.height;
    CGFloat viewHeight = self.view.bounds.size.height;

    // On iPad, the form is presented in a popover view
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + navBarHeight - viewHeight), 0.0)];
    } else {
        CGFloat statBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + statBarHeight + navBarHeight - viewHeight), 0.0)];
    }
    
    // Set colors, fonts, etc.
    [self applyColorPalette];
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // Adjust content inset
        // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
        CGFloat navBarHeight = self.navigationController.navigationBar.bounds.size.height;
        CGFloat tableHeight = self.editImageParamsTableView.bounds.size.height;

        // On iPad, the form is presented in a popover view
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            self.preferredContentSize = CGSizeMake(kEditImageParamsViewWidth, ceil(CGRectGetHeight(mainScreenBounds)*2/3));
            [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + navBarHeight - size.height), 0.0)];
        } else {
            CGFloat statBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
            [self.editImageParamsTableView setContentInset:UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, tableHeight + statBarHeight + navBarHeight - size.height), 0.0)];
        }

        // Reload collection and table views
        [self.editImageThumbnailCollectionView reloadData];
        [self.editImageParamsTableView reloadData];
    } completion:nil];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Return updated parameters or nil
    if ([self.delegate respondsToSelector:@selector(didFinishEditingParams:)])
    {
        [self.delegate didFinishEditingParams:self.commonParameters];
    }
    
    // Unregister palette changes
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPiwigoNotificationPaletteChanged object:nil];
}


#pragma mark - Edit image Methods

-(void)cancelEdit
{
    // No change
    self.commonParameters = nil;
    
    // Return to image preview
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)doneEdit
{
    // Initialise new image list and time shift
    NSMutableArray *updatedImages = [[NSMutableArray alloc] init];

    // Update all images
    for (NSInteger index = 0; index < self.images.count; index++)
    {
        // Next image
        PiwigoImageData *imageData = [self.images objectAtIndex:index];
        
        // Update image title?
        if (self.commonParameters.imageTitle && self.shouldUpdateTitle) {
            imageData.imageTitle = self.commonParameters.imageTitle;
        }

        // Update image author?
        if (self.commonParameters.author && self.shouldUpdateAuthor) {
            imageData.author = self.commonParameters.author;
        }

        // Update image creation date?
        if (self.shouldUpdateDateCreated) {
            imageData.dateCreated = self.commonParameters.dateCreated;
        } else {
            imageData.dateCreated = self.oldCreationDate;
        }
        
        // Update image privacy level?
        if ((self.commonParameters.privacyLevel != NSNotFound) && self.shouldUpdatePrivacyLevel) {
            imageData.privacyLevel = self.commonParameters.privacyLevel;
        }

        // Update image tags?
        if (self.shouldUpdateTags) {
            imageData.tags = self.commonParameters.tags;
        }

        // Update image description?
        if ((self.commonParameters.comment) && self.shouldUpdateComment) {
            imageData.comment = self.commonParameters.comment;
        }
        
        // Append image data
        [updatedImages addObject:imageData];
    }
    self.images = updatedImages;
    self.imagesToUpdate = [self.images mutableCopy];
    
    // Start updating Piwigo database
    [self updateImageProperties];
}

-(void)updateImageProperties
{
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUpdatingImageInfoHUD];
    });
    
    // Update image info on server and in cache
    [ImageService setImageProperties:[self.imagesToUpdate lastObject]
                           onProgress:^(NSProgress *progress) {
                            // Progress
                            }
                          OnCompletion:^(NSURLSessionTask *task, NSDictionary *response)
                            {
                                if (response != nil) {
                                    // Next image?
                                    [self.imagesToUpdate removeLastObject];
                                    if (self.imagesToUpdate.count) {
                                        [self updateImageProperties];
                                    }
                                    else {
                                        // Hide HUD
                                        [self hideUpdatingImageInfoHUDwithSuccess:YES completion:^{
                                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                                                // Return to image preview or album view
                                                [self dismissViewControllerAnimated:YES completion:nil];
                                            });
                                        }];
                                    }
                                } else {
                                    // Failed
                                    [self hideUpdatingImageInfoHUDwithSuccess:NO completion:^{
                                        [self showErrorMessage];
                                    }];
                                }
                            }
                             onFailure:^(NSURLSessionTask *task, NSError *error) {
                                // Failed
                                [self hideUpdatingImageInfoHUDwithSuccess:NO completion:^{
                                    [self showErrorMessage];
                                }];
                            }];
}

-(void)showErrorMessage
{
    UIAlertController* alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"editImageDetailsError_title", @"Failed to Update")
            message:NSLocalizedString(@"editImageDetailsError_message", @"Failed to update your changes with your server\nTry again?")
            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                    style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction * action) {
                    }];

    UIAlertAction* dismissAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertDismissButton", @"Dismiss")
                    style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction * action) {
                        // Bypass this image
                        [self.imagesToUpdate removeLastObject];
                        // Next image
                        if (self.imagesToUpdate.count) [self updateImageProperties];
                    }];

    UIAlertAction* retryAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                    style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction * action) {
                        [self updateImageProperties];
                    }];

    [alert addAction:cancelAction];
    if (self.imagesToUpdate.count > 2) [alert addAction:dismissAction];
    [alert addAction:retryAction];
    if (@available(iOS 13.0, *)) {
        alert.overrideUserInterfaceStyle = [Model sharedInstance].isDarkPaletteActive ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
    } else {
        // Fallback on earlier versions
    }
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - HUD Methods

-(void)showUpdatingImageInfoHUD
{
    // Create the loading HUD if needed
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if (!hud) {
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
    
    // Change the background view shape, style and color.
    hud.square = NO;
    hud.animationType = MBProgressHUDAnimationFade;
    hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.5f];
    hud.contentColor = [UIColor piwigoHudContentColor];
    hud.bezelView.color = [UIColor piwigoHudBezelViewColor];

    // Define the text
    hud.label.text = NSLocalizedString(@"editImageDetailsHUD_updating", @"Updating Image Info…");
    hud.label.font = [UIFont piwigoFontNormal];
}

-(void)hideUpdatingImageInfoHUDwithSuccess:(BOOL)success completion:(void (^)(void))completion
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hide and remove the HUD
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        if (hud) {
            if (success) {
                UIImage *image = [[UIImage imageNamed:@"completed"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                hud.customView = imageView;
                hud.mode = MBProgressHUDModeCustomView;
                hud.label.text = NSLocalizedString(@"completeHUD_label", @"Complete");
                [hud hideAnimated:YES afterDelay:2.f];
            } else {
                [hud hideAnimated:YES];
            }
        }
        if (completion) {
            completion();
        }
    });
}


#pragma mark - UICollectionView - Rows

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    // Returns number of images or albums
    return self.images.count;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    // Avoid unwanted spaces
    if (@available(iOS 13.0, *)) {
        return UIEdgeInsetsMake(0, kImageDetailsMarginsSpacing, 0, kImageDetailsMarginsSpacing);
    } else {
        return UIEdgeInsetsMake(10, kImageDetailsMarginsSpacing, 0, kImageDetailsMarginsSpacing);
    }
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
{
    return (CGFloat)kImageDetailsCellSpacing;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat size = (CGFloat)[ImagesCollection imageDetailsSizeForView:self.view];
    return CGSizeMake(size, 144);
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    EditImageFilenameCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"image" forIndexPath:indexPath];
    if (!cell) {
        cell = [EditImageFilenameCollectionViewCell new];
    }
    [cell setupWithImage:self.images[indexPath.row] andRemoveOption:(self.images.count > 1)];
    cell.delegate = self;
    return cell;
}


#pragma mark - UITableView - Rows

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.0;        // To hide the section header
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 44.0;
    NSInteger row = indexPath.row;
    if (self.images.count > 1) {
        // Bypass the creation date
        if (row > EditImageParamsOrderAuthor) row++;
    }
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
    {
        case EditImageParamsOrderDatePicker:
            height = 259.0;     // 1 point removed, toolbar above picker to hide border
            break;
        
        case EditImageParamsOrderPrivacy:
        case EditImageParamsOrderTags:
            height = 73.0;
            break;
            
        case EditImageParamsOrderDescription:
            height = 528.0;
            break;

        default:
            break;
    }

    return height;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return EditImageParamsOrderCount - (self.images.count > 1) - (self.hasDatePicker == NO);
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [UITableViewCell new];

    NSInteger row = indexPath.row;
    if (self.images.count > 1) {
        // Bypass the creation date
        if (row > EditImageParamsOrderAuthor) row++;
    }
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
	{
        case EditImageParamsOrderImageName:
		{
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"title" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImageTextFieldTableViewCell new];
            }
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_title", @"Title")
                     placeHolder:NSLocalizedString(@"editImageDetails_titlePlaceholder", @"Title")
                  andImageDetail:self.commonParameters.imageTitle];
            cell.cellTextField.tag = EditImageParamsOrderImageName;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
            break;
		}
		
        case EditImageParamsOrderAuthor:
		{
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"author" forIndexPath:indexPath];
            if(!cell) {
                cell = [EditImageTextFieldTableViewCell new];
            }
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_author", @"Author")
                     placeHolder:NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name")
                  andImageDetail:[self.commonParameters.author isEqualToString:@"NSNotFound"] ? @"" : self.commonParameters.author];
            cell.cellTextField.tag = EditImageParamsOrderAuthor;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
			break;
		}
		
        case EditImageParamsOrderDate:
        {
            EditImageTextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"dateCreation" forIndexPath:indexPath];
            if(!cell) {
                cell = [EditImageTextFieldTableViewCell new];
            }
            [cell setupWithLabel:NSLocalizedString(@"editImageDetails_dateCreation", @"Creation Date")
                     placeHolder:@""
                  andImageDetail:[self getStringFromDate:self.commonParameters.dateCreated]];
            cell.cellTextField.tag = EditImageParamsOrderDate;
            cell.cellTextField.delegate = self;
            tableViewCell = cell;
            break;
        }
        
        case EditImageParamsOrderDatePicker:
        {
            EditImageDatePickerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kDatePickerTableCell_ID forIndexPath:indexPath];
            if(!cell) {
                cell = [EditImageDatePickerTableViewCell new];
            }
            [cell setDatePickerWithDate:self.commonParameters.dateCreated animated:NO];
            [cell setDatePickerButtons];
            cell.delegate = self;
            tableViewCell = cell;
            break;
        }
        
        case EditImageParamsOrderPrivacy:
		{
			EditImagePrivacyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"privacy" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImagePrivacyTableViewCell new];
            }
			[cell setLeftLabelText:NSLocalizedString(@"editImageDetails_privacyLevel", @"Who can see this photo?")];
			[cell setPrivacyLevel:self.commonParameters.privacyLevel];
            tableViewCell = cell;
			break;
		}
		
        case EditImageParamsOrderTags:
		{
			EditImageTagsTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tags" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImageTagsTableViewCell new];
            }
			[cell setTagList:self.commonParameters.tags];
            tableViewCell = cell;
			break;
		}
		
        case EditImageParamsOrderDescription:
		{
			EditImageTextViewTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"description" forIndexPath:indexPath];
            if (!cell) {
                cell = [EditImageTextViewTableViewCell new];
            }
            [cell setupWithImageDetail:self.commonParameters.comment];
            cell.textView.delegate = self;
            tableViewCell = cell;
			break;
		}
	}
	
    tableViewCell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    tableViewCell.tintColor = [UIColor piwigoOrange];
	return tableViewCell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger row = indexPath.row;
    if (self.images.count > 1) {
        // Bypass the creation date
        if (row > EditImageParamsOrderAuthor) row++;
    }
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
    {
        case EditImageParamsOrderPrivacy:
        {
            // Deselect row
            [tableView deselectRowAtIndexPath:indexPath animated:YES];

            // Dismiss the keyboard
            [self.view endEditing:YES];
            
            // Create view controller
            SelectPrivacyViewController *privacySelectVC = [SelectPrivacyViewController new];
            privacySelectVC.delegate = self;
            [privacySelectVC setPrivacy:(kPiwigoPrivacy)self.commonParameters.privacyLevel];
            [self.navigationController pushViewController:privacySelectVC animated:YES];
            break;
        }
            
        case EditImageParamsOrderTags:
        {
            // Deselect row
            [tableView deselectRowAtIndexPath:indexPath animated:YES];

            // Dismiss the keyboard
            [self.view endEditing:YES];
            
            // Create view controller
            TagsViewController *tagsVC = [TagsViewController new];
            tagsVC.delegate = self;
            tagsVC.alreadySelectedTags = [self.commonParameters.tags mutableCopy];
            [self.navigationController pushViewController:tagsVC animated:YES];
            break;
        }
        
        default:
            break;
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL result;
    NSInteger row = indexPath.row;
    if (self.images.count > 1) {
        // Bypass the creation date
        if (row > EditImageParamsOrderAuthor) row++;
    }
    if (self.hasDatePicker == NO) {
        // Bypass the date picker
        if (row > EditImageParamsOrderDate) row++;
    }
    switch (row)
    {
        case EditImageParamsOrderImageName:
        case EditImageParamsOrderAuthor:
        case EditImageParamsOrderDate:
        case EditImageParamsOrderDescription:
            result = NO;
            break;
            
        default:
            result = YES;
    }
    
    return result;
}


#pragma mark - UITextFieldDelegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (textField.tag == EditImageParamsOrderDate) {
        // The common date can be nil or past distant (i.e. unset)
        if (self.commonParameters.dateCreated == nil) {
            // Define date as today
            self.commonParameters.dateCreated = [NSDate date];
            self.shouldUpdateDateCreated = YES;
            
            // Update creation date
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDate inSection:0];
            UITableViewCell *cell = [self.editImageParamsTableView cellForRowAtIndexPath:indexPath];
            if ([cell isKindOfClass:[EditImageTextFieldTableViewCell class]]) {
                EditImageTextFieldTableViewCell *dateCell = (EditImageTextFieldTableViewCell *)cell;
                [dateCell setupWithLabel:NSLocalizedString(@"editImageDetails_dateCreation", @"Creation Date")
                             placeHolder:@""
                          andImageDetail:[self getStringFromDate:self.commonParameters.dateCreated]];
                [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:NO];
            }
        }
        
        // Show date of hide picker
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDatePicker inSection:0];
        if (self.hasDatePicker) {
            // Found a picker, so remove it
            self.hasDatePicker = NO;
            [self.editImageParamsTableView beginUpdates];
            [self.editImageParamsTableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [self.editImageParamsTableView endUpdates];
        }
        else {
            // Didn't find a picker, so we should insert it
            self.hasDatePicker = YES;
            [self.editImageParamsTableView beginUpdates];
            [self.editImageParamsTableView insertRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [self.editImageParamsTableView endUpdates];
        }

        // Prevent keyboard from opening
        return NO;
    }
    
    return YES;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.shouldUpdateTitle = YES;
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            self.shouldUpdateAuthor = YES;
            break;
        }
    }
}

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *finalString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = finalString;
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            if (finalString.length > 0) {
                self.commonParameters.author = finalString;
            } else {
                self.commonParameters.author = @"NSNotFound";
            }
            break;
        }
    }
    return YES;
}

-(BOOL)textFieldShouldClear:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = @"";
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            self.commonParameters.author = @"NSNotFound";
            break;
        }
    }
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.editImageParamsTableView endEditing:YES];
    return YES;
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    switch (textField.tag)
    {
        case EditImageParamsOrderImageName:
        {
            // Title
            self.commonParameters.imageTitle = textField.text;
            break;
        }
            
        case EditImageParamsOrderAuthor:
        {
            // Author
            if (textField.text.length > 0) {
                self.commonParameters.author = textField.text;
            } else {
                self.commonParameters.author = @"NSNotFound";
            }
            break;
        }
    }
}


#pragma mark - UITextViewDelegate Methods

-(void)textViewDidBeginEditing:(UITextView *)textView
{
    self.shouldUpdateComment = YES;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    NSString *finalString = [textView.text stringByReplacingCharactersInRange:range withString:text];
    self.commonParameters.comment = finalString;
    return YES;
}

-(BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    [self.editImageParamsTableView endEditing:YES];
    return YES;
}

-(void)textViewDidEndEditing:(UITextView *)textView
{
    self.commonParameters.comment = textView.text;
}


#pragma mark - EditImageFilenameDelegate Methods

-(void)didDeselectImageWithId:(NSInteger)imageId
{
    // Update data source
    NSMutableArray *newImages = [[NSMutableArray alloc] initWithArray:self.images];
    for (ImageUpload *imageData in self.images)
    {
        if (imageData.imageId == imageId)
        {
            [newImages removeObject:imageData];
        }
    }
    self.images = newImages;
    [self.editImageThumbnailCollectionView reloadData];
    [self.editImageParamsTableView reloadData];

    // Deselect image in album view
    if ([self.delegate respondsToSelector:@selector(didDeselectImageToEdit:)])
    {
        [self.delegate didDeselectImageToEdit:imageId];
    }
}

-(void)didRenameFileOfImageWithId:(NSInteger)imageId andFilename:(NSString *)fileName
{
    // Update data source
    PiwigoImageData *updatedImage;
    NSMutableArray *updatedImages = [[NSMutableArray alloc] init];
    for (PiwigoImageData *imageData in self.images)
    {
        if (imageData.imageId == imageId)
        {
            if (fileName) imageData.fileName = fileName;
            updatedImage = imageData;
        }
        [updatedImages addObject:imageData];
    }
    self.images = updatedImages;
    
    // Update image details cell
    for (EditImageFilenameCollectionViewCell *cell in self.editImageThumbnailCollectionView.visibleCells)
    {
        // Look for right image details cell
        if (cell.imageId == imageId)
        {
            [cell setupWithImage:updatedImage andRemoveOption:(self.images.count > 1)];
        }
    }

    // Update parent image view
    if ([self.delegate respondsToSelector:@selector(didRenameFileOfImage:)])
    {
        [self.delegate didRenameFileOfImage:updatedImage];
    }
}


# pragma mark -  EditImageDatePickerDelegate Methods

-(void)didSelectDateWithPicker:(NSDate *)date
{
    // Apply new date
    self.shouldUpdateDateCreated = YES;
    self.commonParameters.dateCreated = date;
    
    // Update cell
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDate inSection:0];
    [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

-(void)didUnsetImageCreationDate
{
    self.commonParameters.dateCreated = nil;
    self.shouldUpdateDateCreated = YES;
    
    // Close date picker
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDatePicker inSection:0];
    if (self.hasDatePicker) {
        self.hasDatePicker = NO;
        [self.editImageParamsTableView beginUpdates];
        [self.editImageParamsTableView deleteRowsAtIndexPaths:@[indexPath]
                         withRowAnimation:UITableViewRowAnimationFade];
        [self.editImageParamsTableView endUpdates];
    }

    // Update creation date cell
    indexPath = [NSIndexPath indexPathForRow:EditImageParamsOrderDate inSection:0];
    [self.editImageParamsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark - SelectPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
	// Update image parameter
    self.commonParameters.privacyLevel = privacy;
	
    // Update table view cell
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(EditImageParamsOrderPrivacy - (self.images.count > 1) - (self.hasDatePicker == NO)) inSection:0];
    EditImagePrivacyTableViewCell *cell = (EditImagePrivacyTableViewCell*)[self.editImageParamsTableView cellForRowAtIndexPath:indexPath];
	if (cell) [cell setPrivacyLevel:privacy];
    
    // Remember to update image info
    self.shouldUpdatePrivacyLevel = YES;
}


#pragma mark - TagsViewControllerDelegate Methods

-(void)didExitWithSelectedTags:(NSArray *)selectedTags
{
    // Update image parameter
	self.commonParameters.tags = selectedTags;

    // Update table view cell
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(EditImageParamsOrderTags - (self.images.count > 1) - (self.hasDatePicker == NO)) inSection:0];
    EditImageTagsTableViewCell *cell = (EditImageTagsTableViewCell*)[self.editImageParamsTableView cellForRowAtIndexPath:indexPath];
    if (cell) [cell setTagList:self.commonParameters.tags];

    // Remember to update image info
    self.shouldUpdateTags = YES;
}


#pragma mark - Utilities

-(NSString *)getStringFromDate:(NSDate *)date
{
    NSString *dateStr = @""; NSString *timeStr = @"";
    if (date != nil) {
        if(self.view.bounds.size.width > 375) {     // i.e. larger than iPhones 6,7,8 screen width
            dateStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle];
            timeStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        } else if(self.view.bounds.size.width > 320) {     // i.e. larger than iPhone 5 screen width
            dateStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
            timeStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        } else {
            dateStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
            timeStr = [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        }
    }
    return [NSString stringWithFormat:@"%@ %@", dateStr, timeStr];
}
@end
