//
//  EditImageDetailsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
#import "EditImageDetailsViewController.h"
#import "EditImageTextFieldTableViewCell.h"
#import "EditImageTextViewTableViewCell.h"
#import "EditImageLabelTableViewCell.h"
#import "TagsTableViewCell.h"
#import "ImageUpload.h"
#import "ImageService.h"
#import "MBProgressHUD.h"
#import "SelectPrivacyViewController.h"
#import "TagsViewController.h"
#import "UploadService.h"

CGFloat const kEditImageDetailsWidth = 512.0;      // EditImageDetails view width

typedef enum {
	EditImageDetailsOrderImageName,
	EditImageDetailsOrderAuthor,
	EditImageDetailsOrderPrivacy,
	EditImageDetailsOrderTags,
	EditImageDetailsOrderDescription,
	EditImageDetailsOrderCount
} EditImageDetailsOrder;

@interface EditImageDetailsViewController () <UITableViewDelegate, UITableViewDataSource,  SelectPrivacyDelegate, TagsViewControllerDelegate>

@property (nonatomic, weak) IBOutlet UITableView *editImageDetailsTableView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewBottomConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *tableViewTopConstraint;
@property (nonatomic, assign) BOOL shouldUpdateDetails;

@end

@implementation EditImageDetailsViewController

-(void)awakeFromNib
{
	[super awakeFromNib];
	
    self.title = NSLocalizedString(@"imageDetailsView_title", @"Image Details");
	
    // Register palette changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(paletteChanged) name:kPiwigoNotificationPaletteChanged object:nil];
}

#pragma mark - View Lifecycle

-(void)paletteChanged
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBarHidden = NO;
    
    // Table view
    self.editImageDetailsTableView.backgroundColor = [UIColor piwigoBackgroundColor];
    self.editImageDetailsTableView.separatorColor = [UIColor piwigoSeparatorColor];

    EditImageTextFieldTableViewCell *textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderImageName inSection:0]];
    [textFieldCell paletteChanged];
    
    textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderAuthor inSection:0]];
    [textFieldCell paletteChanged];
    
    EditImageLabelTableViewCell *privacyCell = (EditImageLabelTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderPrivacy inSection:0]];
    [privacyCell paletteChanged];
    
    TagsTableViewCell *tagCell = (TagsTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderTags inSection:0]];
    [tagCell paletteChanged];

    EditImageTextViewTableViewCell *textViewCell = (EditImageTextViewTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderDescription inSection:0]];
    [textViewCell paletteChanged];

    [self.editImageDetailsTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Register for keyboard notifications
    [self registerForKeyboardNotifications];
    
    // Set colors, fonts, etc.
    [self paletteChanged];

    // Navigation buttons in edition mode
    self.shouldUpdateDetails = NO;
    if(self.isEdit)
    {
		UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelEdit)];
		UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEdit)];
		
		self.navigationItem.leftBarButtonItem = cancel;
		self.navigationItem.rightBarButtonItem = done;
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Unregister for keyboard notifications while not visible.
    [self unregisterKeyboardNotifications];

    if ((self.shouldUpdateDetails || (self.navigationItem.rightBarButtonItem == nil)) &&
        [self.delegate respondsToSelector:@selector(didFinishEditingDetails:)])
	{
		[self prepareImageForChanges];
		[self.delegate didFinishEditingDetails:self.imageDetails];
	}
}

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    //Reload the tableview on orientation change, to match the new width of the table.
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
        // On iPad, the Settings section is presented in a centered popover view
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            CGRect mainScreenBounds = [UIScreen mainScreen].bounds;
            self.preferredContentSize = CGSizeMake(kEditImageDetailsWidth, ceil(CGRectGetHeight(mainScreenBounds)*2/3));
        }
        
        // Reload table view
        [self.editImageDetailsTableView reloadData];
    } completion:nil];
}

-(void)prepareImageForChanges
{
	[self updateImageDetails];
}

// NOTE: make sure that you set the image data before you set isEdit so it can download the appropriate data
-(void)setIsEdit:(BOOL)isEditChoice
{
    _isEdit = isEditChoice;
}

-(void)cancelEdit
{
    self.shouldUpdateDetails = NO;
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)doneEdit
{
	// Update image details
    [self prepareImageForChanges];
	
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUpdatingImageInfoHUD];
    });
    
    // Update image info on server and in cache
	[UploadService updateImageInfo:self.imageDetails
						onProgress:^(NSProgress *progress) {
							// Progress
						}
                      OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
							
                            // Complete, update image data
                            self.shouldUpdateDetails = YES;
                          
                            // Hide HUD
                            [self hideUpdatingImageInfoHUDwithSuccess:YES completion:^{
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                                    // Return to image preview
                                    [self dismissViewControllerAnimated:YES completion:nil];
                                });
                            }];
						}
                         onFailure:^(NSURLSessionTask *task, NSError *error) {
							// Failed
                            [self hideUpdatingImageInfoHUDwithSuccess:NO completion:^{
                                UIAlertController* alert = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"editImageDetailsError_title", @"Failed to Update")
                                        message:NSLocalizedString(@"editImageDetailsError_message", @"Failed to update your changes with your server\nTry again?")
                                        preferredStyle:UIAlertControllerStyleAlert];
                                
                                UIAlertAction* dismissAction = [UIAlertAction
                                                actionWithTitle:NSLocalizedString(@"alertCancelButton", @"Cancel")
                                                style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction * action) {
                                                    self.shouldUpdateDetails = NO;
                                                }];

                                UIAlertAction* retryAction = [UIAlertAction
                                                actionWithTitle:NSLocalizedString(@"alertRetryButton", @"Retry")
                                                style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * action) {
                                                    [self doneEdit];
                                                }];

                                [alert addAction:dismissAction];
                                [alert addAction:retryAction];
                                [self presentViewController:alert animated:YES completion:nil];
                             }];
						}];
}


#pragma mark - HUD methods

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


#pragma mark - Keyboard Notifications

- (void)registerForKeyboardNotifications {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

// Called when the UIKeyboardWillShowNotification is sent.
- (void)keyboardWillShow:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGRect kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey]
                     CGRectValue];
    double duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey]
                       doubleValue];
    
    UIEdgeInsets insets = self.editImageDetailsTableView.contentInset;
    insets.bottom += (self.editImageDetailsTableView.frame.origin.y + self.editImageDetailsTableView.frame.size.height) - self.view.bounds.size.height + kbSize.size.height;
    
    [UIView animateWithDuration:duration animations:^{
        self.editImageDetailsTableView.contentInset = insets;
    }];

    EditImageTextFieldTableViewCell *textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderImageName inSection:0]];
    if ([textFieldCell isEditingTextField]) {
        // Scroll the table so that the cells of interest are visible
        [self.editImageDetailsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderImageName inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }

    textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderAuthor inSection:0]];
    if ([textFieldCell isEditingTextField]) {
        // Scroll the table so that the cells of interest are visible
        [self.editImageDetailsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderAuthor inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }

    EditImageTextViewTableViewCell *textViewCell = (EditImageTextViewTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderDescription inSection:0]];
    if ([textViewCell isEditingTextView]) {
        // Scroll the table so that the cells of interest are visible
        [self.editImageDetailsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderDescription inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillHide:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    double duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey]
                       doubleValue];
    
    // Reset the text view's bottom content inset.
    UIEdgeInsets insets = self.editImageDetailsTableView.contentInset;
    insets.bottom = 0;
    
    [UIView animateWithDuration:duration animations:^{
        self.editImageDetailsTableView.contentInset = insets;
    }];

    [self.editImageDetailsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderImageName inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
}

- (void)unregisterKeyboardNotifications {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}


#pragma mark - Keyboard Methods

-(void)updateImageDetails
{
	// Title
    EditImageTextFieldTableViewCell *textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderImageName inSection:0]];
	self.imageDetails.title = textFieldCell.getTextFieldText;
	
    // Author
	textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderAuthor inSection:0]];
    if (textFieldCell.getTextFieldText.length > 0) {
        self.imageDetails.author = textFieldCell.getTextFieldText;
    } else {
        self.imageDetails.author = @"NSNotFound";
    }
	
    // Description
	EditImageTextViewTableViewCell *textViewCell = (EditImageTextViewTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderDescription inSection:0]];
	self.imageDetails.imageDescription = textViewCell.getTextViewText;
}


#pragma mark - UITableView - Rows

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.0;        // To hide the section header
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ((indexPath.row == EditImageDetailsOrderPrivacy) ||
        (indexPath.row == EditImageDetailsOrderTags)) return 68.0;
    if (indexPath.row == EditImageDetailsOrderDescription) return 100.0;
	return 44.0;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return EditImageDetailsOrderCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [UITableViewCell new];
	
	switch(indexPath.row)
	{
		case EditImageDetailsOrderImageName:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"title"];
			[((EditImageTextFieldTableViewCell*)cell) setLabel:NSLocalizedString(@"editImageDetails_title", @"Title:") andTextField:self.imageDetails.title withPlaceholder:NSLocalizedString(@"editImageDetails_titlePlaceholder", @"Title")];
			break;
		}
		case EditImageDetailsOrderAuthor:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"author"];
            NSString *author = self.imageDetails.author;
            if ([self.imageDetails.author isEqualToString:@"NSNotFound"]) {
                author = @"";
            }
			[((EditImageTextFieldTableViewCell*)cell) setLabel:NSLocalizedString(@"editImageDetails_author", @"Author:") andTextField:author withPlaceholder:NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name")];
			break;
		}
		case EditImageDetailsOrderPrivacy:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"privacy"];
			[((EditImageLabelTableViewCell*)cell) setLeftLabelText:NSLocalizedString(@"editImageDetails_privacyLevel", @"Who can see this photo?")];
			[((EditImageLabelTableViewCell*)cell) setPrivacyLevel:self.imageDetails.privacyLevel];
			break;
		}
		case EditImageDetailsOrderTags:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"tags"];
			[((TagsTableViewCell*)cell) setTagList:self.imageDetails.tags];
			break;
		}
		case EditImageDetailsOrderDescription:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"description"];
			[((EditImageTextViewTableViewCell*)cell) setTextForTextView:self.imageDetails.imageDescription];
			break;
		}
	}
	
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
	return cell;
}


#pragma mark - UITableViewDelegate Methods

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if (indexPath.row == EditImageDetailsOrderPrivacy)
	{
        // Dismiss the keyboard
        [self.view endEditing:YES];
        
        // Store recent modifications
        [self updateImageDetails];
        
        // Create view controller
        SelectPrivacyViewController *privacySelectVC = [SelectPrivacyViewController new];
		privacySelectVC.delegate = self;
		[privacySelectVC setPrivacy:self.imageDetails.privacyLevel];
		[self.navigationController pushViewController:privacySelectVC animated:YES];
	}
	else if (indexPath.row == EditImageDetailsOrderTags)
	{
        // Dismiss the keyboard
        [self.view endEditing:YES];
        
        // Store recent modifications
        [self updateImageDetails];
        
        // Create view controller
		TagsViewController *tagsVC = [TagsViewController new];
		tagsVC.delegate = self;
		tagsVC.alreadySelectedTags = [self.imageDetails.tags mutableCopy];
		[self.navigationController pushViewController:tagsVC animated:YES];
    }
    else if (indexPath.row == EditImageDetailsOrderAuthor) {
        if ([self.imageDetails.author isEqualToString:@"NSNotFound"]) { // only update if not yet set, dont overwrite
            if (0 < [[[Model sharedInstance] defaultAuthor] length]) {  // must know the default author
                self.imageDetails.author = [[Model sharedInstance] defaultAuthor];
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }
	
}


#pragma mark - SelectPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
	self.imageDetails.privacyLevel = privacy;
	
	EditImageLabelTableViewCell *labelCell = (EditImageLabelTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderPrivacy inSection:0]];
	[labelCell setPrivacyLevel:privacy];
}


#pragma mark - TagsViewControllerDelegate Methods

-(void)didExitWithSelectedTags:(NSArray *)selectedTags
{
	self.imageDetails.tags = selectedTags;
	[self.editImageDetailsTableView reloadData];
}

@end
