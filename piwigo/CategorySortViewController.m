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
		self.view.backgroundColor = [UIColor whiteColor];
		self.title = @"Sort Type"; // @TODO: Localize this!
		
		self.sortSelectTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
		self.sortSelectTableView.translatesAutoresizingMaskIntoConstraints = NO;
		self.sortSelectTableView.delegate = self;
		self.sortSelectTableView.dataSource = self;
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
			name = @"Name Ascending";
			break;
		case kPiwigoSortCategoryNameDescending:
			name = @"Name Descending";
			break;
		case kPiwigoSortCategoryFileNameAscending:
			name = @"File Name Ascending";
			break;
		case kPiwigoSortCategoryFileNameDescending:
			name = @"File Name Descending";
			break;
		case kPiwigoSortCategoryDateCreatedAscending:
			name = @"Date Ascending";
			break;
		case kPiwigoSortCategoryDateCreatedDescending:
			name = @"Date Descending (most recent first)";
			break;
		case kPiwigoSortCategoryIdAscending:
			name = @"Image ID Ascending";
			break;
		case kPiwigoSortCategoryIdDescending:
			name = @"Image ID Descending";
			break;
			
		case kPiwigoSortCategoryCount:
			break;
	}
	return name;
}

@end
