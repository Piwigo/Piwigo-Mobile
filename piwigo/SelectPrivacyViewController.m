//
//  SelectPrivacyViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SelectPrivacyViewController.h"
#import "Model.h"

@interface SelectPrivacyViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *privacyTableView;

@end

@implementation SelectPrivacyViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoWhiteCream];
		self.title = @"Privacy Level";	// @TODO: Localize this!
		
		self.privacyTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.privacyTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.privacyTableView.delegate = self;
		self.privacyTableView.dataSource = self;
		self.privacyTableView.backgroundColor = [UIColor piwigoWhiteCream];
		[self.view addSubview:self.privacyTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.privacyTableView]];
		
		
		
	}
	return self;
}

-(kPiwigoPrivacy)getPrivacyLevelForRow:(NSInteger)row
{
	kPiwigoPrivacy privacyLevel = 0;
	switch(row)
	{
		case 0:
			privacyLevel = 0;
			break;
		case 1:
			privacyLevel = 1;
			break;
		case 2:
			privacyLevel = 2;
			break;
		case 3:
			privacyLevel = 4;
			break;
		case 4:
			privacyLevel = 8;
			break;
	}
	
	return privacyLevel;
}

#pragma mark UITableView Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return kPiwigoPrivacyCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
	}
	
	kPiwigoPrivacy privacyLevel = [self getPrivacyLevelForRow:indexPath.row];
	
	if(privacyLevel == [Model sharedInstance].defaultPrivacyLevel)
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
	cell.textLabel.text = [[Model sharedInstance] getNameForPrivacyLevel:privacyLevel];
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	kPiwigoPrivacy selectedPrivacy = [self getPrivacyLevelForRow:indexPath.row];
	
	[Model sharedInstance].defaultPrivacyLevel = selectedPrivacy;
	[[Model sharedInstance] saveToDisk];
	[tableView reloadData];
	
	[self.navigationController popViewControllerAnimated:YES];
}

@end
