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
		self.title = NSLocalizedString(@"privacyLevel", @"Privacy Level");
		
		self.privacyTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.privacyTableView.backgroundColor = [UIColor clearColor];
        self.privacyTableView.separatorColor = [UIColor piwigoSeparatorColor];
		self.privacyTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.privacyTableView.delegate = self;
		self.privacyTableView.dataSource = self;
		[self.view addSubview:self.privacyTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.privacyTableView]];
		
	}
	return self;
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
    
    // Tab bar appearance
    self.tabBarController.tabBar.barTintColor = [UIColor piwigoBackgroundColor];
    self.tabBarController.tabBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 10, *)) {
        self.tabBarController.tabBar.unselectedItemTintColor = [UIColor piwigoTextColor];
    }
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoTextColor]} forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor piwigoOrange]} forState:UIControlStateSelected];

    // Table view
    self.privacyTableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.privacyTableView reloadData];
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
    // Header height?
    NSString *header = NSLocalizedString(@"settings_defaultPrivacy>414px", @"Who Can See the Media?");
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:nil];
    return ceil(headerRect.size.height + 4.0 + 10.0);
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.text = NSLocalizedString(@"settings_defaultPrivacy>414px", @"Who Can See the Media?");
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
    // Header height
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontNormal]};
    CGRect headerRect = [headerLabel.text boundingRectWithSize:CGSizeMake(tableView.frame.size.width, CGFLOAT_MAX)
                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                    attributes:attributes
                                                       context:nil];
    
    // Header view
    UIView *header = [[UIView alloc] initWithFrame:headerRect];
    header.backgroundColor = [UIColor clearColor];
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:4]];
    if (@available(iOS 11, *)) {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[header]-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    } else {
        [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                       options:kNilOptions
                                                                       metrics:nil
                                                                         views:@{@"header" : headerLabel}]];
    }
    
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
	
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
    cell.textLabel.adjustsFontSizeToFitWidth = NO;
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
