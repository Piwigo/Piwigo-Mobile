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
#import "LoadingView.h"

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

@end

@implementation EditImageDetailsViewController

-(void)awakeFromNib
{
	[super awakeFromNib];
	
	self.title = @"Edit Image Details";
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillDismiss:) name:UIKeyboardWillHideNotification object:nil];
}

// NOTE: make sure that you set the image data before you set isEdit so it can download the appropriate data
-(void)setIsEdit:(BOOL)isEdit
{
	_isEdit = isEdit;
	[ImageService getImageInfoById:self.imageDetails.imageId
				  ListOnCompletion:^(AFHTTPRequestOperation *operation, PiwigoImageData *imageData) {
					  self.imageDetails = [[ImageUpload alloc] initWithImageData:imageData];
					  [self.editImageDetailsTableView reloadData];
				  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
					  [UIAlertView showWithTitle:NSLocalizedString(@"imageDetailsFetchError_title", @"Image Details Fetch Failed")
										 message:NSLocalizedString(@"imageDetailsFetchError_message", @"Fetching the image data failed\nTry again?")
							   cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
							   otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
										tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
											if(buttonIndex == 1)
											{
												self.isEdit = _isEdit;
											}
										}];
				  }];
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	self.navigationController.navigationBarHidden = NO;
	
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
	
	if(self.imageDetails.imageUploadName.length == 0)
	{
		self.imageDetails.imageUploadName = self.imageDetails.image;
	}
}

-(void)cancelEdit
{
	[self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

-(void)doneEdit
{
	[self prepareImageForChanges];
	
	LoadingView *loading = [LoadingView new];
	[self.view addSubview:loading];
	[self.view addConstraints:[NSLayoutConstraint constraintCenterView:loading]];
	[loading showLoadingWithLabel:@"Setting Image Information" andProgressLabel:nil];
	
	[UploadService updateImageInfo:self.imageDetails
						onProgress:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
							// progress
						} OnCompletion:^(AFHTTPRequestOperation *operation, NSDictionary *response) {
							// complete
							[loading hideLoadingWithLabel:@"Saved" showCheckMark:YES withDelay:0.3];
							[self.navigationController dismissViewControllerAnimated:YES completion:nil];
						} onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
							[loading hideLoadingWithLabel:@"Failed" showCheckMark:NO withDelay:0.0];
							[UIAlertView showWithTitle:@"Failed to Update"
											   message:@"Failed to update your changes with your server\nTry again?"
									 cancelButtonTitle:@"No"
									 otherButtonTitles:@[@"Yes"]
											  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
												  if(buttonIndex == 1)
												  {
													  [self doneEdit];
												  }
											  }];
						}];
}

-(void)updateImageDetails
{
	EditImageTextFieldTableViewCell *textFieldCell = (EditImageTextFieldTableViewCell*)[self.editImageDetailsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:EditImageDetailsOrderImageName inSection:0]];
	self.imageDetails.imageUploadName = textFieldCell.getTextFieldText;
	
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

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
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
			[((EditImageTextFieldTableViewCell*)cell) setLabel:NSLocalizedString(@"editImageDetails_name", @"Image Name") andTextField:self.imageDetails.imageUploadName withPlaceholder:NSLocalizedString(@"editImageDetails_name", @"Image Name")];
			break;
		}
		case EditImageDetailsOrderAuthor:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"textField"];
			[((EditImageTextFieldTableViewCell*)cell) setLabel:NSLocalizedString(@"editImageDetails_author", @"Author") andTextField:self.imageDetails.author withPlaceholder:NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author Name")];
			break;
		}
		case EditImageDetailsOrderPrivacy:
		{
			cell = [tableView dequeueReusableCellWithIdentifier:@"label"];
			[((EditImageLabelTableViewCell*)cell) setLeftLabelText:NSLocalizedString(@"privacyLevel", @"Privacy Level")];
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
