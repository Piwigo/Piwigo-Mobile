//
//  CategorySortViewController.m
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "CategorySortViewController.h"

@interface CategorySortViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *sortSelectTableView;

@end


@implementation CategorySortViewController

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.view.backgroundColor = [UIColor piwigoGray];
		self.title = NSLocalizedString(@"sortTitle", @"Sort Type");
		
		self.sortSelectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.sortSelectTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.sortSelectTableView.delegate = self;
		self.sortSelectTableView.dataSource = self;
        self.sortSelectTableView.backgroundColor = [UIColor piwigoGray];
		[self.view addSubview:self.sortSelectTableView];
		[self.view addConstraints:[NSLayoutConstraint constraintFillSize:self.sortSelectTableView]];
	}
	return self;
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
    return 50.0;
}

-(UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 50)];
    
    UILabel *headerLabel = [UILabel new];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    headerLabel.font = [UIFont piwigoFontNormal];
    headerLabel.textColor = [UIColor piwigoOrange];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    headerLabel.text = NSLocalizedString(@"defaultImageSort>414px", @"Default Sort of Images");
    headerLabel.adjustsFontSizeToFitWidth = YES;
    headerLabel.minimumScaleFactor = 0.5;
    [header addSubview:headerLabel];
    [header addConstraint:[NSLayoutConstraint constraintViewFromBottom:headerLabel amount:10]];
    [header addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[header]-15-|"
                                                                   options:kNilOptions
                                                                   metrics:nil
                                                                     views:@{@"header" : headerLabel}]];
    
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
