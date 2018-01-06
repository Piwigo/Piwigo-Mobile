//
//  EditImageDetailsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageDetailsViewController.h"
#import "EditImageTextFieldTableViewCell.h"
#import "EditImageTextViewTableViewCell.h"
#import "EditImageLabelTableViewCell.h"
#import "TagsTableViewCell.h"
#import "ImageUpload.h"
#import "SelectPrivacyViewController.h"
#import "TagsViewController.h"
#import "ImageService.h"
#import "UploadService.h"
#import "MBProgressHUD.h"

typedef enum {
	EditImageDetailsOrderImageName,
	EditImageDetailsOrderAuthor,
	EditImageDetailsOrderPrivacy,
	EditImageDetailsOrderTags,
	EditImageDetailsOrderDescription,
	EditImageDetailsOrderCount
} EditImageDetailsOrder;

@interface EditImageDetailsViewController () <UITableViewDelegate, UITableViewDataSource, SelectPrivacyDelegate, TagsViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableView *editImageDetailsTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewTopConstraint;

@end

@implementation EditImageDetailsViewController

-(void)awakeFromNib
{
	[super awakeFromNib];
	
    self.title = NSLocalizedString(@"imageDetailsView_title", @"Image Details");
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillDismiss:) name:UIKeyboardWillHideNotification object:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Navigation bar appearence
    NSDictionary *attributes = @{
                                 NSForegroundColorAttributeName: [UIColor piwigoWhiteCream],
                                 NSFontAttributeName: [UIFont piwigoFontNormal],
                                 };
    self.navigationController.navigationBar.titleTextAttributes = attributes;
    [self.navigationController.navigationBar setTintColor:[UIColor piwigoOrange]];
    [self.navigationController.navigationBar setBarTintColor:[UIColor piwigoBackgroundColor]];
    self.navigationController.navigationBar.barStyle = [Model sharedInstance].isDarkPaletteActive ? UIBarStyleBlack : UIBarStyleDefault;
    self.navigationController.navigationBarHidden = NO;

    // Tab bar appearance
    self.tabBarController.tabBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.tabBarController.tabBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 10, *)) {
        self.tabBarController.tabBar.unselectedItemTintColor = [UIColor piwigoTextColor];
    }
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoTextColor]} forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoOrange]} forState:UIControlStateSelected];

    // Table view
    self.editImageDetailsTableView.backgroundColor = [UIColor piwigoBackgroundColor];
    self.editImageDetailsTableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.editImageDetailsTableView reloadData];
    
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
    
    if([self.delegate respondsToSelector:@selector(didFinishEditingDetails:)])
	{
		[self prepareImageForChanges];
		[self.delegate didFinishEditingDetails:self.imageDetails];
	}
}

-(void)prepareImageForChanges
{
	[self updateImageDetails];
	
    // Set image title to filename without extension if not defined
	if(self.imageDetails.title.length == 0)
	{
		self.imageDetails.title = [self.imageDetails.image stringByDeletingPathExtension];
	}
}

// NOTE: make sure that you set the image data before you set isEdit so it can download the appropriate data
-(void)setIsEdit:(BOOL)isEdit
{
    _isEdit = isEdit;
    [ImageService getImageInfoById:self.imageDetails.imageId
                  ListOnCompletion:^(NSURLSessionTask *task, PiwigoImageData *imageData) {
                      self.imageDetails = [[ImageUpload alloc] initWithImageData:imageData];
                      [self.editImageDetailsTableView reloadData];
                  } onFailure:^(NSURLSessionTask *task, NSError *error) {
                      // Failed — Ask user if he/she wishes to retry
                      UIAlertController* alert = [UIAlertController
                                                  alertControllerWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed")
                                                  message:NSLocalizedString(@"imageDetailsFetchError_retryMessage", @"Fetching the image data failed\nTry again?")
                                                  preferredStyle:UIAlertControllerStyleAlert];
                      
                      UIAlertAction* dismissAction = [UIAlertAction
                                                      actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                                      style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * action) {}];
                      
                      UIAlertAction* retryAction = [UIAlertAction
                                                      actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
                                                      style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * action) {
                                                          self.isEdit = _isEdit;
                                                      }];

                      [alert addAction:dismissAction];
                      [alert addAction:retryAction];
                      [self presentViewController:alert animated:YES completion:nil];
                  }];
}

-(void)cancelEdit
{
	[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

-(void)doneEdit
{
	// Update image details
    [self prepareImageForChanges];
	
    // Display HUD during the update
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showUpdatingImageInfoHUD];
    });
    
    // Update image info
	[UploadService updateImageInfo:self.imageDetails
						onProgress:^(NSProgress *progress) {
							// progress
						} OnCompletion:^(NSURLSessionTask *task, NSDictionary *response) {
							// complete
                            [self hideUpdatingImageInfoHUDwithSuccess:YES completion:^{
                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 700 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                                    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
                                });
                            }];
						} onFailure:^(NSURLSessionTask *task, NSError *error) {
							// Failed
                            [self hideUpdatingImageInfoHUDwithSuccess:NO completion:^{
                                UIAlertController* alert = [UIAlertController
                                        alertControllerWithTitle:NSLocalizedString(@"editImageDetailsError_title", @"Failed to Update")
                                        message:NSLocalizedString(@"editImageDetailsError_message", @"Failed to update your changes with your server\nTry again?")
                                        preferredStyle:UIAlertControllerStyleAlert];
                                
                                UIAlertAction* dismissAction = [UIAlertAction
                                                actionWithTitle:NSLocalizedString(@"alertNoButton", @"No")
                                                style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction * action) {}];

                                UIAlertAction* retryAction = [UIAlertAction
                                                actionWithTitle:NSLocalizedString(@"alertYesButton", @"Yes")
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

#pragma mark -- HUD methods

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


#pragma mark -- Keyboard Methods

-(void)updateImageDetails
{
	EditImageTextFieldTableViewCell *textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderImageName inSection:0]];
	self.imageDetails.title = textFieldCell.getTextFieldText;
	
	textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderAuthor inSection:0]];
	self.imageDetails.author = textFieldCell.getTextFieldText;
	
	EditImageTextViewTableViewCell *textViewCell = (EditImageTextViewTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderDescription inSection:0]];
	self.imageDetails.imageDescription = textViewCell.getTextViewText;
}

-(void)keyboardWillChange:(NSNotification*)notification
{
	CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardRect = [self.view convertRect:keyboardRect fromView:nil];
	
	self.tableViewBottomConstraint.constant = keyboardRect.size.height;
}

-(void)keyboardWillDismiss:(NSNotification*)notification
{
	self.tableViewBottomConstraint.constant = 0;
}

#pragma mark UITableView methods

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.0;        // To hide the section header
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if((indexPath.row == EditImageDetailsOrderPrivacy) ||(indexPath.row == EditImageDetailsOrderTags)) return 68.0;
    if(indexPath.row == EditImageDetailsOrderDescription) return 100.0;
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
			cell = [tableView dequeueReusableCellWithIdentifier:@"textField"];
			[((EditImageTextFieldTableViewCell*)cell) setLabel:NSLocalizedString(@"editImageDetails_title", @"Title:") andTextField:self.imageDetails.title withPlaceholder:NSLocalizedString(@"editImageDetails_titlePlaceholder", @"Title")];
			break;
		}
		case EditImageDetailsOrderAuthor:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"textField"];
			[((EditImageTextFieldTableViewCell*)cell) setLabel:NSLocalizedString(@"editImageDetails_author", @"Author:") andTextField:self.imageDetails.author withPlaceholder:NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name")];
			break;
		}
		case EditImageDetailsOrderPrivacy:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"label"];
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
			cell = [tableView dequeueReusableCellWithIdentifier:@"textArea"];
			[((EditImageTextViewTableViewCell*)cell) setTextForTextView:self.imageDetails.imageDescription];
			break;
		}
	}
	
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if(indexPath.row == EditImageDetailsOrderPrivacy)
	{
		SelectPrivacyViewController *privacySelectVC = [SelectPrivacyViewController new];
		privacySelectVC.delegate = self;
		[privacySelectVC setPrivacy:self.imageDetails.privacyLevel];
		[self.navigationController pushViewController:privacySelectVC animated:YES];
	}
	else if(indexPath.row == EditImageDetailsOrderTags)
	{
		TagsViewController *tagsVC = [TagsViewController new];
		tagsVC.delegate = self;
		tagsVC.alreadySelectedTags = [self.imageDetails.tags mutableCopy];
		[self.navigationController pushViewController:tagsVC animated:YES];
    } else if (indexPath.row == EditImageDetailsOrderAuthor) {
        if (0 == self.imageDetails.author.length) { // only update if not yet set, dont overwrite
            if (0 < [[[Model sharedInstance] defaultAuthor] length]) { // must know the default author
                self.imageDetails.author = [[Model sharedInstance] defaultAuthor];
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }
	
}

#pragma mark SelectPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
	self.imageDetails.privacyLevel = privacy;
	
	EditImageLabelTableViewCell *labelCell = (EditImageLabelTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderPrivacy inSection:0]];
	[labelCell setPrivacyLevel:privacy];
}

#pragma mark TagsViewControllerDelegate Methods

-(void)didExitWithSelectedTags:(NSArray *)selectedTags
{
	self.imageDetails.tags = selectedTags;
	[self.editImageDetailsTableView reloadData];
}

@end
