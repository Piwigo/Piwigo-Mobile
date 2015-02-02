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

typedef enum {
	SettingSectionServer,
	SettingSectionLogout,
	SettingSectionImageUpload,
	SettingSectionAbout,
	SettingSectionCount
} SettingSection;

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate>

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
							   @3,
							   @1,
							   @4,
							   @2
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
}

#pragma mark -- UITableView Methods

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
	
	return [UITableViewCell new];
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section
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
	switch(indexPath.section)
	{
		case SettingSectionServer:
			break;
		case SettingSectionLogout:
			[self logout];
			break;
		case SettingSectionImageUpload:
			break;
		case SettingSectionAbout:
			break;
	}
}

#pragma mark -- Option Methods

-(void)logout
{
	[UIAlertView showWithTitle:@"Logout"
					   message:@"Are you sure you want to logout?"
			 cancelButtonTitle:@"No"
			 otherButtonTitles:@[@"Yes"]
					  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
						  if(buttonIndex == 1)
						  {
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


@end
