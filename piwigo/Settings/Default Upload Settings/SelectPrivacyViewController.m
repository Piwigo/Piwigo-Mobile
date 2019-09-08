//
//  SelectPrivacyViewController.m
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "AppDelegate.h"
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
		self.title = NSLocalizedString(@"tabBar_upload", @"Upload");
		
		self.privacyTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.privacyTableView.backgroundColor = [UIColor clearColor];
        self.privacyTableView.separatorColor = [UIColor piwigoSeparatorColor];
		self.privacyTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.privacyTableView.delegate = self;
		self.privacyTableView.dataSource = self;
		[self.view addSubview:self.privacyTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.privacyTableView]];
		
        // Register palette changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyPaletteSettings) name:kPiwigoNotificationPaletteChanged object:nil];
	}
	return self;
}

#pragma mark - View Lifecycle

-(void)applyPaletteSettings
{
    // Background color of the view
    self.view.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Navigation bar
    self.navigationController.navigationBar.backgroundColor = [UIColor piwigoBackgroundColor];
    self.navigationController.navigationBar.tintColor = [UIColor piwigoOrange];
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = NO;
    }
    
    // Table view
    self.privacyTableView.indicatorStyle = [Model sharedInstance].isDarkPaletteActive ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleBlack;
    [self.privacyTableView reloadData];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set colors, fonts, etc.
    [self applyPaletteSettings];
}

-(void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    
    // User may have switched to Light or Dark Mode
    if (@available(iOS 13.0, *)) {
        BOOL isDarkMode = (newCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [appDelegate setColorSettingsWithiOSInDarkMode:isDarkMode];
    } else {
        // Fallback on earlier versions
    }
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


#pragma mark - UITableView - Header

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"privacyLevel", @"Privacy Level")];
    NSDictionary *titleAttributes = @{NSFontAttributeName: [UIFont piwigoFontBold]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect titleRect = [titleString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:titleAttributes
                                                 context:context];
    
    // Text
    NSString *textString = NSLocalizedString(@"settings_defaultPrivacy>414px", @"Please select who will be able to see images");
    NSDictionary *textAttributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    CGRect textRect = [textString boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:textAttributes
                                               context:context];
    return fmax(44.0, ceil(titleRect.size.height + textRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSMutableAttributedString *headerAttributedString = [[NSMutableAttributedString alloc] initWithString:@""];
    
    // Title
    NSString *titleString = [NSString stringWithFormat:@"%@\n", NSLocalizedString(@"privacyLevel", @"Privacy Level")];
    NSMutableAttributedString *titleAttributedString = [[NSMutableAttributedString alloc] initWithString:titleString];
    [titleAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontBold]
                                  range:NSMakeRange(0, [titleString length])];
    [headerAttributedString appendAttributedString:titleAttributedString];
    
    // Text
    NSString *textString = NSLocalizedString(@"settings_defaultPrivacy>414px", @"Please select who will be able to see images");
    NSMutableAttributedString *textAttributedString = [[NSMutableAttributedString alloc] initWithString:textString];
    [textAttributedString addAttribute:NSFontAttributeName value:[UIFont piwigoFontSmall]
                                 range:NSMakeRange(0, [textString length])];
    [headerAttributedString appendAttributedString:textAttributedString];
    
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    headerLabel.attributedText = headerAttributedString;
    
    // Header view
    UIView *header = [[UIView alloc] init];
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


#pragma mark - UITableView - Rows

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return kPiwigoPrivacyCount;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
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


#pragma mark - UITableViewDelegate Methods

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
