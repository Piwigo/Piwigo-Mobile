//
//  SettingsViewController.m
//  piwigo
//
//  Created by Spencer Baker on 1/20/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SettingsViewController.h"
#import "SessionService.h"
#import "AppDelegate.h"
#import "Model.h"
#import "SelectPrivacyViewController.h"
#import "TextFieldTableViewCell.h"
#import "ButtonTableViewCell.h"
#import "LabelTableViewCell.h"
#import "AboutViewController.h"
#import "ClearCache.h"
#import "SliderTableViewCell.h"

typedef enum {
	SettingSectionServer,
	SettingSectionLogout,
	SettingSectionImageUpload,
	SettingSectionCache,
	SettingSectionAbout,
	SettingSectionCount
} SettingSection;

typedef enum {
	kImageUploadSettingAuthor
} kImageUploadSetting;

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, SelectPrivacyDelegate>

@property (nonatomic, strong) UITableView *settingsTableView;
@property (nonatomic, strong) NSArray *rowsInSection;
@property (nonatomic, strong) NSArray *headerHeights;
@property (nonatomic, strong) NSLayoutConstraint *topConstraint;
@property (nonatomic, strong) NSLayoutConstraint *tableViewBottomConstraint;

@end

@implementation SettingsViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor whiteColor];
		
		self.rowsInSection = @[
							   @2,
							   @1,
							   @2,
							   @2,
							   @1
							   ];
		self.headerHeights = @[
							   @40.0,
							   @5.0,
							   @30.0,
							   @30.0,
							   @20.0
							   ];
		
		self.settingsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.settingsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.settingsTableView.backgroundColor = [UIColor piwigoGray];
		self.settingsTableView.delegate = self;
		self.settingsTableView.dataSource = self;
		[self.view addSubview:self.settingsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillWidth:self.settingsTableView]];
		[self.view addConstraint:[NSLayoutConstraint constraintViewFromTop:self.settingsTableView amount:0]];
		self.tableViewBottomConstraint = [NSLayoutConstraint constraintViewFromBottom:self.settingsTableView amount:0];
		[self.view addConstraint:self.tableViewBottomConstraint];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillDismiss:) name:UIKeyboardWillHideNotification object:nil];
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self.settingsTableView reloadData];
}

-(void)viewWillDisappear:(BOOL)animated
{
	SliderTableViewCell *diskCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SettingSectionCache]];
	[Model sharedInstance].diskCache = [diskCell getCurrentSliderValue];
	
	SliderTableViewCell *memoryCell = (SliderTableViewCell*)[self.settingsTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:SettingSectionCache]];
	[Model sharedInstance].memoryCache = [memoryCell getCurrentSliderValue];
	[[Model sharedInstance] saveToDisk];
	
	NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:[Model sharedInstance].memoryCache * 1024*1024
														 diskCapacity:[Model sharedInstance].diskCache * 1024*1024
															 diskPath:nil];
	[NSURLCache setSharedURLCache:URLCache];
	
	[super viewWillDisappear:animated];
}

-(void)keyboardWillChange:(NSNotification*)notification
{
	CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardRect = [self.view convertRect:keyboardRect fromView:nil];
	
	self.tableViewBottomConstraint.constant = -keyboardRect.size.height;
}

-(void)keyboardWillDismiss:(NSNotification*)notification
{
	self.tableViewBottomConstraint.constant = 0;
}

#pragma mark -- UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return SettingSectionCount;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.rowsInSection[section] integerValue];
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *tableViewCell = [UITableViewCell new];
	switch(indexPath.section)
	{
		case SettingSectionServer:
		{
			LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"server"];
			if(!cell)
			{
				cell = [LabelTableViewCell new];
			}
			switch(indexPath.row)
			{
				case 0:
					cell.leftText = NSLocalizedString(@"settings_server", @"Server");
					cell.rightText = [Model sharedInstance].serverName;
					break;
				case 1:
					cell.leftText = NSLocalizedString(@"settings_username", @"Username");
					if([Model sharedInstance].username.length > 0)
					{
						cell.rightText = [Model sharedInstance].username;
					}
					else
					{
						cell.rightText = NSLocalizedString(@"settings_notLoggedIn", @" - Not Logged In - ");
					}
					break;
			}
			tableViewCell = cell;
			break;
		}
		case SettingSectionLogout:
		{
			ButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
			if(!cell)
			{
				cell = [ButtonTableViewCell new];
			}
			if([Model sharedInstance].username.length > 0)
			{
				cell.buttonText = NSLocalizedString(@"settings_logout", @"Logout");
			}
			else
			{
				cell.buttonText = NSLocalizedString(@"login", @"Login");
			}
			tableViewCell = cell;
			break;
		}
		case SettingSectionImageUpload:
		{
			switch(indexPath.row)
			{
				case 0:
				{
					TextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"uploadSettingsField"];
					if(!cell)
					{
						cell = [TextFieldTableViewCell new];
					}
					
					cell.labelText = NSLocalizedString(@"settings_defaultAuthor", @"Default Author");
					cell.rightTextField.text = [Model sharedInstance].defaultAuthor;
					cell.rightTextField.placeholder = NSLocalizedString(@"settings_defaultAuthorPlaceholder", @"Author");
					cell.rightTextField.delegate = self;
					cell.rightTextField.tag = kImageUploadSettingAuthor;
					
					tableViewCell = cell;
					break;
				}
				case 1:
				{
					LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"server"];
					if(!cell)
					{
						cell = [LabelTableViewCell new];
					}
					
					cell.leftText = NSLocalizedString(@"settings_defaultPrivacy", @"Default Privacy");
					cell.rightText = [[Model sharedInstance] getNameForPrivacyLevel:[Model sharedInstance].defaultPrivacyLevel];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					cell.leftLabelWidth = 120;
					
					tableViewCell = cell;
					break;
				}
			}
			break;
		}
		case SettingSectionCache:
		{
			switch(indexPath.row)
			{
				case 0:
				{
					SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsMem"];
					if(!cell)
					{
						cell = [SliderTableViewCell new];
					}
					cell.cacheType.text = @"Disk";	// @TODO: Localize this!
					cell.sliderValue = [Model sharedInstance].diskCache;
					
					tableViewCell = cell;
					break;
				}
				case 1:
				{
					SliderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sliderSettingsDisk"];
					if(!cell)
					{
						cell = [SliderTableViewCell new];
					}
					cell.cacheType.text = @"Memory";	// @TODO: Localize this!
					cell.sliderValue = [Model sharedInstance].memoryCache;
					
					tableViewCell = cell;
					break;
				}
//				case 2:
//				{
//					ButtonTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"clearCacheButton"];
//					if(!cell)
//					{
//						cell = [ButtonTableViewCell new];
//					}
//					cell.buttonText = @"Clear Cache";
//					cell.buttonLabel.textColor = [UIColor redColor];
//					
//					tableViewCell = cell;
//					break;
//				}
			}
			break;
		}
		case SettingSectionAbout:
		{
			LabelTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"server"];
			if(!cell)
			{
				cell = [LabelTableViewCell new];
			}
			
			cell.leftText = NSLocalizedString(@"settings_about", @"About Piwigo Mobile");
			cell.leftLabel.textAlignment = NSTextAlignmentLeft;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.leftLabelWidth = 220;
			
			tableViewCell = cell;
			break;
		}
	}
	
	return tableViewCell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return [self.headerHeights[section] floatValue];
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, [self.headerHeights[section] floatValue])];
	header.backgroundColor = [UIColor clearColor];
	
	CGRect labelFrame = header.frame;
	labelFrame.origin.x += 15;
	
	UILabel *headerLabel = [[UILabel alloc] initWithFrame:labelFrame];
	headerLabel.font = [UIFont piwigoFontNormal];
	headerLabel.textColor = [UIColor whiteColor];
	[header addSubview:headerLabel];
	
	switch(section)
	{
		case SettingSectionServer:
			headerLabel.text = NSLocalizedString(@"settingsHeader_server", @"Piwigo Server");
			break;
		case SettingSectionImageUpload:
			headerLabel.text = NSLocalizedString(@"settingsHeader_imageSettings", @"Image Upload Settings");
			break;
		case SettingSectionCache:
			headerLabel.text = @"Image Cache Settings"; // @TODO: Localize this!
			break;
		case SettingSectionAbout:
			headerLabel.text = NSLocalizedString(@"settingsHeader_about", @"About");
			break;
	}
	
	return header;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	switch(indexPath.section)
	{
		case SettingSectionServer:
			break;
		case SettingSectionLogout:
			[self logout];
			break;
		case SettingSectionImageUpload:
			if(indexPath.row == 1)
			{
				SelectPrivacyViewController *selectPrivacy = [SelectPrivacyViewController new];
				selectPrivacy.delegate = self;
				[selectPrivacy setPrivacy:[Model sharedInstance].defaultPrivacyLevel];
				[self.navigationController pushViewController:selectPrivacy animated:YES];
			}
			break;
//		case SettingSectionCache:
//			if(indexPath.row == 2)
//			{
//				[UIAlertView showWithTitle:@"DELETE IMAGE CACHE"	// @TODO: Localize these!
//								   message:@"Are you sure you want to clear your image cache?\nThis will make images take a while to load again."
//						 cancelButtonTitle:@"No"
//						 otherButtonTitles:@[@"Yes"]
//								  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
//									  if(buttonIndex == 1)
//									  {
//										  // set it to 0 to clear it
//										  NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:0
//																							   diskCapacity:0
//																								   diskPath:nil];
//										  [NSURLCache setSharedURLCache:URLCache];
//										  
//										  // set it back
//										  URLCache = [[NSURLCache alloc] initWithMemoryCapacity:500 * 1024 * 1024	// @TODO: set this from the model
//																				   diskCapacity:500 * 1024 * 1024
//																					   diskPath:nil];
//										  [NSURLCache setSharedURLCache:URLCache];
//									  }
//								  }];
//			}
//			break;
		case SettingSectionAbout:
		{
			AboutViewController *aboutVC = [AboutViewController new];
			[self.navigationController pushViewController:aboutVC animated:YES];
			break;
		}
	}
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	[self.view endEditing:YES];
}

#pragma mark -- Option Methods

-(void)logout
{
	if([Model sharedInstance].username.length > 0)
	{
		[UIAlertView showWithTitle:NSLocalizedString(@"logoutConfirmation_title", @"Logout")
						   message:NSLocalizedString(@"logoutConfirmation_message", @"Are you sure you want to logout?")
				 cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
				 otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
						  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
							  if(buttonIndex == 1)
							  {
								  [SessionService sessionLogoutOnCompletion:^(AFHTTPRequestOperation *operation, BOOL sucessfulLogout) {
									  if(sucessfulLogout)
									  {
										  [ClearCache clearAllCache];
										  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
										  [appDelegate loadLoginView];
									  }
									  else
									  {
										  [UIAlertView showWithTitle:NSLocalizedString(@"logoutFail_title", @"Logout Failed")
															 message:NSLocalizedString(@"logoutFail_message", @"Failed to logout\nTry again?")
												   cancelButtonTitle:NSLocalizedString(@"alertNoButton", @"No")
												   otherButtonTitles:@[NSLocalizedString(@"alertYesButton", @"Yes")]
															tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
																if(buttonIndex == 1)
																{
																	[self logout];
																}
															}];
									  }
								  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
									  
								  }];
							  }
						  }];
	}
	else
	{
		[ClearCache clearAllCache];
		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate loadLoginView];
	}
}

#pragma mark UITextFieldDelegate Methods

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	switch(textField.tag)
	{
		case kImageUploadSettingAuthor:
		{
			NSMutableString *textFieldString = [textField.text mutableCopy];
			[textFieldString insertString:string atIndex:range.location];
			[Model sharedInstance].defaultAuthor = textFieldString;
			[[Model sharedInstance] saveToDisk];
			break;
		}
	}
	
	return YES;
}

#pragma mark SelectedPrivacyDelegate Methods

-(void)selectedPrivacy:(kPiwigoPrivacy)privacy
{
	[Model sharedInstance].defaultPrivacyLevel = privacy;
	[[Model sharedInstance] saveToDisk];
}


@end
