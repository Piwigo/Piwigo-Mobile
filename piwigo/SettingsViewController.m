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

typedef enum {
	SettingSectionServer,
	SettingSectionLogout,
	SettingSectionImageUpload,
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
							   @4,
							   @1
							   ];
		self.headerHeights = @[
							   @40.0,
							   @5.0,
							   @30.0,
							   @20.0
							   ];
		
		self.settingsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.settingsTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.settingsTableView.backgroundColor = [UIColor piwigoGray];
		self.settingsTableView.delegate = self;
		self.settingsTableView.dataSource = self;
		[self.view addSubview:self.settingsTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.settingsTableView]];
		
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[self.settingsTableView reloadData];
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
					cell.leftText = @"Server";	// @TODO: Localize this
					cell.rightText = [Model sharedInstance].serverName;
					break;
				case 1:
					cell.leftText = @"Username";	// @TODO: Localize this
					cell.rightText = [Model sharedInstance].username;	// @TODO: if not logged in, put this as "not logged in"
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
			cell.buttonText = @"Logout";	// @TODO: Localize this
			// @TODO: If they're not logged in, make this login instead of logout
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
					
					cell.labelText = @"Default Author";	// @TODO: localize this
					cell.rightTextField.text = [Model sharedInstance].defaultAuthor;
					cell.rightTextField.placeholder = @"Author";	// @TODO: localize this
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
					
					cell.leftText = @"Default Privacy";
					cell.rightText = [[Model sharedInstance] getNameForPrivacyLevel:[Model sharedInstance].defaultPrivacyLevel];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					cell.leftLabelWidth = 120;
					
					tableViewCell = cell;
					break;
				}
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
			
			cell.leftText = @"About Piwigo Mobile";	// @TODO: Localize this!
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
			headerLabel.text = @"Piwigo Server";
			break;
		case SettingSectionImageUpload:
			headerLabel.text = @"Image Upload Settings";
			break;
		case SettingSectionAbout:
			headerLabel.text = @"About";
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
	[UIAlertView showWithTitle:@"Logout"	// @TODO: localize these
					   message:@"Are you sure you want to logout?"
			 cancelButtonTitle:@"No"
			 otherButtonTitles:@[@"Yes"]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
							  // @TODO: show a logging out spinner
							  [SessionService sessionLogoutOnCompletion:^(AFHTTPRequestOperation *operation, BOOL sucessfulLogout) {
								  if(sucessfulLogout)
								  {
									  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
									  [appDelegate loadLoginView];
								  }
								  else
								  {
									  // @TODO: show logout error
								  }
							  } onFailure:^(AFHTTPRequestOperation *operation, NSError *error) {
								  
							  }];
						  }
					  }];
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
