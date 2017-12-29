//
//  SelectPrivacyViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SelectPrivacyViewController.h"

@interface SelectPrivacyViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *privacyTableView;
@property (nonatomic, assign) kPiwigoPrivacy privacy;

@end

@implementation SelectPrivacyViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.title = NSLocalizedString(@"privacyLevel", @"Privacy Level");
		
		self.privacyTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.privacyTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.privacyTableView.delegate = self;
		self.privacyTableView.dataSource = self;
		self.privacyTableView.backgroundColor = [UIColor piwigoGray];
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

-(void)setPrivacy:(kPiwigoPrivacy)privacy
{
	_privacy = privacy;
}

#pragma mark UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 64.0;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
    
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoOrange];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.text = NSLocalizedString(@"settings_defaultPrivacy>414px", @"Who Can See the Media?");
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    
    return header;
}

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
	
	if(privacyLevel == self.privacy)
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
	cell.textLabel.text = [[Model sharedInstance] getNameForPrivacyLevel:privacyLevel];
	cell.tag = privacyLevel;
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	kPiwigoPrivacy selectedPrivacy = [self getPrivacyLevelForRow:indexPath.row];
	
	for(UITableViewCell *visibleCell in tableView.visibleCells)
	{
		visibleCell.accessoryType = UITableViewCellAccessoryNone;
		if(visibleCell.tag == selectedPrivacy)
		{
			visibleCell.accessoryType = UITableViewCellAccessoryCheckmark;
		}
	}
	
	
	if([self.delegate respondsToSelector:@selector(selectedPrivacy:)])
	{
		[self.delegate selectedPrivacy:selectedPrivacy];
	}
	
	[self.navigationController popViewControllerAnimated:YES];
}

@end
