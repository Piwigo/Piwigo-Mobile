//
//  CategorySortViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategorySortViewController.h"
#import "Model.h"

@interface CategorySortViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *sortSelectTableView;

@end


@implementation CategorySortViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoBackgroundColor];
		self.title = NSLocalizedString(@"imageSortTitle", @"Sort Images");
		
		self.sortSelectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
        self.sortSelectTableView.translatesAutoresizingMaskIntoConstraints = NO;
        self.sortSelectTableView.backgroundColor = [UIColor clearColor];
		self.sortSelectTableView.delegate = self;
		self.sortSelectTableView.dataSource = self;
		[self.view addSubview:self.sortSelectTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.sortSelectTableView]];
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
    self.sortSelectTableView.separatorColor = [UIColor piwigoSeparatorColor];
    [self.sortSelectTableView reloadData];
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	if([self.sortDelegate respondsToSelector:@selector(didSelectCategorySortType:)])
	{
		[self.sortDelegate didSelectCategorySortType:self.currentCategorySortType];
	}
}

#pragma mark UITableView Methods

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Header height?
    NSString *header = NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images");
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont piwigoFontSmall]};
    NSStringDrawingContext *context = [[NSStringDrawingContext alloc] init];
    context.minimumScaleFactor = 1.0;
    CGRect headerRect = [header boundingRectWithSize:CGSizeMake(tableView.frame.size.width - 30.0, CGFLOAT_MAX)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes
                                             context:context];
    return fmax(44.0, ceil(headerRect.size.height));
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Header label
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontSmall];
    headerLabel.textColor = [UIColor piwigoHeaderColor];
    headerLabel.text = NSLocalizedString(@"imageSortMessage", @"Please select how you wish to sort images");
    headerLabel.numberOfLines = 0;
    headerLabel.adjustsFontSizeToFitWidth = NO;
    headerLabel.lineBreakMode = NSLineBreakByWordWrapping;
    
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

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return kPiwigoSortCategoryCount;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if(!cell)
	{
		cell = [UITableViewCell new];
	}
	
    cell.backgroundColor = [UIColor piwigoCellBackgroundColor];
    cell.tintColor = [UIColor piwigoOrange];
    cell.textLabel.font = [UIFont piwigoFontNormal];
    cell.textLabel.textColor = [UIColor piwigoLeftLabelColor];
	cell.textLabel.text = [CategorySortViewController getNameForCategorySortType:(kPiwigoSortCategory)indexPath.row];
	cell.textLabel.minimumScaleFactor = 0.5;
	cell.textLabel.adjustsFontSizeToFitWidth = YES;
	cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
	
	if(indexPath.row == self.currentCategorySortType)
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	}
	else
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
	return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	self.currentCategorySortType = (kPiwigoSortCategory)indexPath.row;
	[tableView reloadData];
	[self.navigationController popViewControllerAnimated:YES];
}


+(NSString*)getNameForCategorySortType:(kPiwigoSortCategory)sortType
{
	NSString *name = @"";
	switch(sortType)
	{
		case kPiwigoSortCategoryNameAscending:
			name = NSLocalizedString(@"categorySort_nameAscending", @"Photo Title, A → Z");
			break;
		case kPiwigoSortCategoryNameDescending:
			name = NSLocalizedString(@"categorySort_nameDescending", @"Photo Title, Z → A");
			break;
		case kPiwigoSortCategoryFileNameAscending:
			name = NSLocalizedString(@"categorySort_fileNameAscending", @"File Name, A → Z");
			break;
		case kPiwigoSortCategoryFileNameDescending:
			name = NSLocalizedString(@"categorySort_fileNameDescending", @"File Name, Z → A");
			break;
        case kPiwigoSortCategoryDateCreatedDescending:
            name = NSLocalizedString(@"categorySort_dateCreatedDescending", @"Date Created, new → old");
            break;
        case kPiwigoSortCategoryDateCreatedAscending:
            name = NSLocalizedString(@"categorySort_dateCreatedAscending", @"Date Created, old → new");
            break;
		case kPiwigoSortCategoryDatePostedDescending:
			name = NSLocalizedString(@"categorySort_datePostedDescending", @"Date Posted, new → old");
			break;
		case kPiwigoSortCategoryDatePostedAscending:
			name = NSLocalizedString(@"categorySort_datePostedAscending", @"Date Posted, old → new");
			break;
//		case kPiwigoSortCategoryVideoOnly:
//			name = NSLocalizedString(@"categorySort_videosOnly", @"Videos Only");
//			break;
//		case kPiwigoSortCategoryImageOnly:
//			name = NSLocalizedString(@"categorySort_imagesOnly", @"Images Only");
//			break;
			
		case kPiwigoSortCategoryCount:
			break;
	}
	return name;
}

@end
